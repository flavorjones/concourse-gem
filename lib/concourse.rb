require "concourse/version"
require "concourse/util"
require "concourse/pipeline"
require "yaml"
require "tempfile"

class Concourse
  include Rake::DSL
  include Concourse::Util

  # these numbers/names align with public docker image names
  RUBIES = {
    mri:     %w[2.3 2.4 2.5 2.6], # docker repository: "ruby"
    jruby:   %w[9.1 9.2],     # docker repository: "jruby"
    rbx:     %w[latest],      # docker repository: "rubinius/docker"
    windows: %w[2.3 2.4 2.5 2.6]  # windows-ruby-dev-tools-release
  }

  DEFAULT_DIRECTORY = "concourse"

  attr_reader :project_name
  attr_reader :directory
  attr_reader :pipelines
  attr_reader :fly_target
  attr_reader :secrets_filename

  def self.url_for fly_target
    matching_line = `fly targets`.split("\n").grep(/^#{fly_target}/).first
    raise "invalid fly target #{fly_target}" unless matching_line
    matching_line.split(/ +/)[1]
  end

  def self.default_execute_args task
    args = []
    task["config"]["inputs"].each do |input|
      args << "--input=#{input["name"]}=."
    end
    args.join(" ")
  end

  def self.production_rubies
    RUBIES[:mri].reject { |r| r =~ /rc/ }
  end

  def self.rc_rubies
    RUBIES[:mri].select { |r| r =~ /rc/ }
  end

  def initialize project_name, options={}, &block
    @project_name = project_name

    @directory = options[:directory] || DEFAULT_DIRECTORY
    @fly_target = options[:fly_target] || "default"

    base_secrets_filename = options[:secrets_filename] || "private.yml"
    @secrets_filename = File.join(@directory, base_secrets_filename)

    @pipelines = []
    if block
      block.call(self)
      create_tasks!
    else
      add_pipeline(@project_name, (options[:pipeline_erb_filename] || "#{project_name}.yml"))
    end
  end

  def add_pipeline name, erb_filename
    @pipelines << Concourse::Pipeline.new(name, @directory, erb_filename)
  end

  def pipeline_subcommands command
    pipelines.collect { |p| "#{command}:#{p.name}" }
  end

  def rake_init
    FileUtils.mkdir_p File.join(directory, "tasks")
    pipelines.each do |pipeline|
      FileUtils.touch pipeline.erb_filename
      ensure_in_gitignore pipeline.filename
    end
    ensure_in_gitignore secrets_filename
  end

  def rake_pipeline_generate pipeline
    File.open pipeline.filename, "w" do |f|
      f.write erbify_file(pipeline.erb_filename, working_directory: directory)
    end
    sh "fly validate-pipeline -c #{pipeline.filename}"
  end

  def create_tasks!
    unless Dir.exist? directory
      mkdir_p directory
    end

    pipelines.each do |pipeline|
      CLOBBER.include pipeline.filename if defined?(CLOBBER)

      unless File.exist? pipeline.erb_filename
        warn "WARNING: concourse template #{pipeline.erb_filename.inspect} does not exist, run `rake concourse:init`"
      end
    end

    namespace :concourse do
      #
      #  project commands
      #
      desc "bootstrap a concourse config"
      task :init do
        rake_init
      end

      #
      #  pipeline commands
      #
      desc "generate and validate all pipeline files"
      task "generate" => pipeline_subcommands("generate")

      pipelines.each do |pipeline|
        desc "generate and validate the #{pipeline.name} pipeline file"
        task "generate:#{pipeline.name}" do
          rake_pipeline_generate pipeline
        end
      end

      desc "upload all pipeline files"
      task "set" => pipeline_subcommands("set")

      pipelines.each do |pipeline|
        desc "upload the #{pipeline.name} pipeline file"
        task "set:#{pipeline.name}" => "generate:#{pipeline.name}" do
          options = [
            "-p '#{pipeline.name}'",
            "-c '#{pipeline.filename}'",
          ]
          if File.exist? secrets_filename
            note "using #{secrets_filename} to resolve template vars in #{pipeline.filename}"
            options << "-l '#{secrets_filename}'"
          end
          sh "fly -t #{fly_target} set-pipeline #{options.join(" ")}"
        end
      end

      %w[expose hide pause unpause destroy].each do |command|
        desc "#{command} all pipelines"
        task command => pipeline_subcommands(command)

        pipelines.each do |pipeline|
          desc "#{command} the #{pipeline.name} pipeline"
          task "#{command}:#{pipeline.name}" do
            sh "fly -t #{fly_target} #{command}-pipeline -p #{pipeline.name}"
          end
        end
      end

      desc "remove generated pipeline files"
      task "clean" do
        pipelines.each do |pipeline|
          rm_f pipeline.filename
        end
      end

      #
      #  task commands
      #
      desc "list all available tasks from all pipelines"
      task "tasks" => "generate" do
        tasks = []

        pipelines.each do |pipeline|
          each_task(pipeline) do |job, task|
            tasks << "#{job["name"]}/#{task["task"]}"
          end
        end

        note "Available Concourse tasks for #{project_name} are:"
        tasks.sort.each { |task| puts " * #{task}" }
      end

      desc "fly execute the specified task"
      task "task", [:job_task, :fly_execute_args] => "generate" do |t, args|
        job_task = args[:job_task]
        unless job_task
          raise "ERROR: must specify a task name, like `rake #{t.name}[target,taskname]`"
        end

        concourse_task = find_task(job_task)
        raise "ERROR: could not find task `#{job_task}`" unless concourse_task

        fly_execute_args = args[:fly_execute_args] || Concourse.default_execute_args(concourse_task)

        puts concourse_task.to_yaml
        Tempfile.create("concourse-task") do |f|
          f.write concourse_task["config"].to_yaml
          f.close
          Bundler.with_clean_env do
            sh "fly -t #{fly_target} execute #{fly_execute_args} -c #{f.path}"
          end
        end
      end

      #
      #  builds commands
      #
      desc "abort all running builds for this concourse team"
      task "abort-builds" do |t, args|
        `fly -t #{fly_target} builds`.each_line do |line|
          pipeline_job, build_id, status = *line.split(/\s+/)[1,3]
          next unless status == "started"

          sh "fly -t #{fly_target} abort-build -j #{pipeline_job} -b #{build_id}"
        end
      end

      #
      #  worker commands
      #
      desc "prune any stalled workers"
      task "prune-stalled-workers" do
        `fly -t #{fly_target} workers | fgrep stalled`.each_line do |line|
          worker_id = line.split.first
          system("fly -t #{fly_target} prune-worker -w #{worker_id}")
        end
      end
    end
  end
end
