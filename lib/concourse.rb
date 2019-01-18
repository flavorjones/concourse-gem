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
  attr_reader :pipeline_filename, :pipeline_erb_filename, :pipelines
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

  def initialize project_name, options={}
    @project_name = project_name

    @directory = options[:directory] || DEFAULT_DIRECTORY
    @fly_target = options[:fly_target] || "default"

    pipeline = Concourse::Pipeline.new(@project_name, @directory, options[:pipeline_erb_filename] || "#{project_name}.yml")
    @pipeline_filename = pipeline.filename
    @pipeline_erb_filename = pipeline.erb_filename
    @pipelines = [pipeline]

    base_secrets_filename = options[:secrets_filename] || "private.yml"
    @secrets_filename = File.join(@directory, base_secrets_filename)
  end

  def rake_init
    FileUtils.mkdir_p File.join(directory, "tasks")
    pipelines.each do |pipeline|
      FileUtils.touch pipeline.erb_filename
      ensure_in_gitignore pipeline.filename
    end
    ensure_in_gitignore secrets_filename
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
      desc "generate and validate the pipeline files for #{project_name}"
      task "generate" do |t|
        pipelines.each do |pipeline|
          File.open pipeline.filename, "w" do |f|
            f.write erbify(File.read(pipeline.erb_filename))
          end
          sh "fly validate-pipeline -c #{pipeline.filename}"
        end
      end

      desc "upload the pipeline files for #{project_name}"
      task "set" => ["generate"] do |t, args|
        pipelines.each do |pipeline|
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
        desc "#{command} the #{project_name} pipelines"
        task command do |t, args|
          pipelines.each do |pipeline|
            sh "fly -t #{fly_target} #{command}-pipeline -p #{pipeline.name}"
          end
        end
      end

      desc "remove generate pipeline files"
      task "clean" do |t|
        pipelines.each do |pipeline|
          rm_f pipeline.filename
        end
      end

      #
      #  task commands
      #
      desc "list all the available tasks from the #{project_name} pipelines"
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
      task "prune-stalled-workers" do |t, args|
        `fly -t #{fly_target} workers | fgrep stalled`.each_line do |line|
          worker_id = line.split.first
          system("fly -t #{fly_target} prune-worker -w #{worker_id}")
        end
      end
    end
  end
end
