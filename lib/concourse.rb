require "concourse/version"
require "concourse/util"
require "concourse/pipeline"
require "yaml"
require "tempfile"
require "open-uri"

class Concourse
  include Rake::DSL
  include Concourse::Util

  # these numbers/names align with public docker image names
  RUBIES = {
    mri: %w[2.5 2.6 2.7 3.0-rc], # docker repository: "ruby"
    jruby: %w[9.2], # docker repository: "jruby"
    rbx: %w[latest], # docker repository: "rubinius/docker"
    windows: %w[2.3 2.4 2.5 2.6], # windows-ruby-dev-tools-release
    truffle: %w[stable nightly] # docker repository: flavorjones/truffleruby
  }

  DEFAULT_DIRECTORY = "concourse"
  DEFAULT_FLY_TARGET = "default"
  DEFAULT_SECRETS = "private.yml"

  attr_reader :project_name
  attr_reader :directory
  attr_reader :pipelines
  attr_reader :fly_target
  attr_reader :fly_args
  attr_reader :secrets_filename
  attr_reader :format
  attr_reader :ytt

  CONCOURSE_DOCKER_COMPOSE = "docker-compose.yml"

  def self.url_for(fly_target)
    matching_line = `fly targets`.split("\n").grep(/^#{fly_target}/).first
    raise "invalid fly target #{fly_target}" unless matching_line
    matching_line.split(/ +/)[1]
  end

  def self.default_execute_args(task)
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

  def initialize(project_name, options = {}, &block)
    @project_name = project_name

    @directory = options[:directory] || DEFAULT_DIRECTORY
    @fly_target = options[:fly_target] || DEFAULT_FLY_TARGET
    @format = options.has_key?(:format) ? options[:format] : false
    @ytt = options.has_key?(:ytt) ? options[:ytt] : false
    @fly_args = options.keys.grep(/^fly_args_/).inject({}) do |hash, key|
      fly_command = key.to_s.gsub(/^fly_args_/, "").gsub("_", "-")
      hash[fly_command] = options[key]
      hash
    end

    base_secrets_filename = options[:secrets_filename] || DEFAULT_SECRETS
    @secrets_filename = File.join(@directory, base_secrets_filename)

    @pipelines = []
    if block
      block.call(self)
      create_tasks!
    else
      add_pipeline(@project_name, (options[:pipeline_erb_filename] || "#{project_name}.yml"), {ytt: ytt})
    end
  end

  def add_pipeline(name, erb_filename, options={})
    @pipelines << Concourse::Pipeline.new(name, @directory, erb_filename, options)
  end

  def pipeline_subcommands(command)
    pipelines.collect { |p| "#{command}:#{p.name}" }
  end

  def rake_init
    FileUtils.mkdir_p File.join(directory, "tasks")
    pipelines.each do |pipeline|
      FileUtils.touch pipeline.erb_filename
    end
    ensure_in_gitignore secrets_filename
  end

  def rake_pipeline_generate(pipeline)
    pipeline.generate
    fly "validate-pipeline", "-c #{pipeline.filename}"
    fly "format-pipeline", "-c #{pipeline.filename} -w" if format
  end

  def ensure_docker_compose_file
    return if File.exist?(docker_compose_path)
    note "fetching docker compose file ..."
    File.open(docker_compose_path, "w") do |f|
      f.write URI.open("https://concourse-ci.org/docker-compose.yml").read
      sh "docker pull concourse/concourse"
    end
  end

  def rake_concourse_local
    ensure_docker_compose_file
    @fly_target = "local"
    fly "login", "-u test -p test -c http://127.0.0.1:8080"
  end

  def rake_concourse_local_up
    ensure_docker_compose_file
    docker_compose "up -d"
    docker_compose "ps"
  end

  def rake_concourse_local_down
    ensure_docker_compose_file
    docker_compose "down"
  end

  def create_tasks!
    unless Dir.exist? directory
      mkdir_p directory
    end

    pipelines.each do |pipeline|
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
          fly "set-pipeline", options.join(" ")
        end
      end

      %w[expose hide pause unpause destroy].each do |command|
        desc "#{command} all pipelines"
        task command => pipeline_subcommands(command)

        pipelines.each do |pipeline|
          desc "#{command} the #{pipeline.name} pipeline"
          task "#{command}:#{pipeline.name}" do
            fly "#{command}-pipeline", "-p #{pipeline.name}"
          end
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
          raise "ERROR: must specify a task name, like `rake #{t.name}[taskname]`"
        end

        concourse_task = find_task(job_task)
        raise "ERROR: could not find task `#{job_task}`" unless concourse_task

        fly_execute_args = args[:fly_execute_args] || Concourse.default_execute_args(concourse_task)

        if File.exist? secrets_filename
          note "using #{secrets_filename} to resolve template vars"
          fly_execute_args += " -l '#{secrets_filename}'"
        end

        puts concourse_task.to_yaml

        Tempfile.create("concourse-task") do |f|
          f.write concourse_task["config"].to_yaml
          f.close
          Bundler.with_unbundled_env do
            fly "execute", [fly_execute_args, "-c #{f.path}"].compact.join(" ")
          end
        end
      end

      #
      #  builds commands
      #
      desc "abort all running builds for this concourse team"
      task "abort-builds" do |t, args|
        `fly -t #{fly_target} builds`.each_line do |line|
          pipeline_job, build_id, status = *line.split(/\s+/)[1, 3]
          next unless status == "started"

          fly "abort-build", "-j #{pipeline_job} -b #{build_id}"
        end
      end

      #
      #  worker commands
      #
      desc "prune any stalled workers"
      task "prune-stalled-workers" do
        `fly -t #{fly_target} workers | fgrep stalled`.each_line do |line|
          worker_id = line.split.first
          fly "prune-worker", "-w #{worker_id}"
        end
      end

      #
      #  docker commands
      #
      desc "set fly target to the local docker-compose cluster"
      task "local" do
        rake_concourse_local
      end

      namespace "local" do
        desc "start up a docker-compose cluster for local CI"
        task "up" do
          rake_concourse_local_up
        end

        desc "shut down the docker-compose cluster"
        task "down" do
          rake_concourse_local_down
        end
      end
    end
  end
end
