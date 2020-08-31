require 'term/ansicolor'

class Concourse
  module Util
    include Term::ANSIColor

    GITIGNORE_FILE           = ".gitignore"
    GITATTRIBUTES_FILE       = ".gitattributes"

    def ensure_in_gitignore file_glob
      if File.exist?(GITIGNORE_FILE)
        if File.read(GITIGNORE_FILE).split("\n").include?(file_glob)
          note "found '#{file_glob}' already present in #{GITIGNORE_FILE}"
          return
        end
      end
      note "adding '#{file_glob}' to #{GITIGNORE_FILE}"
      File.open(GITIGNORE_FILE, "a") { |f| f.puts file_glob }
    end

    def fly command, args
      command_args = Array(fly_args[command])
      sh "fly -t #{fly_target} #{command} #{command_args.join(" ")} #{args}"
    end

    def docker_compose command
      sh "docker-compose -f #{docker_compose_path} #{command}"
    end

    def docker_compose_path
      File.join(directory, CONCOURSE_DOCKER_COMPOSE)
    end

    def sh command
      running "(in #{Dir.pwd}) #{command}"
      Rake.sh command, verbose: false
    end

    def running message
      print bold, red, "RUNNING: ", reset, message, "\n"
    end

    def note message
      print bold, green, "NOTE: ", reset, message, "\n"
    end

    def erbify_file filename, working_directory: nil
      raise "ERROR: erbify_file: could not find file `#{filename}`" unless File.exist?(filename)
      template = File.read(filename)

      if working_directory.nil?
        working_directory = "." # so chdir is a no-op below
      else
        fqwd = File.expand_path(working_directory)
        $LOAD_PATH << fqwd unless $LOAD_PATH.include?(fqwd) # so "require" can load relative paths
      end
      Dir.chdir(working_directory) { ERB.new(template, nil, "%-").result(binding) }
    end

    def each_job pipeline
      pdata = YAML.load_file(pipeline.filename)

      pdata["jobs"].each do |job|
        yield job
      end
    end

    def each_task pipeline
      each_job(pipeline) do |job|
        job["plan"].each do |task|
          yield job, task if task["task"]
        end
      end
    end

    def find_task job_task
      job_name, task_name = *job_task.split("/")
      pipelines.each do |pipeline|
        each_task(pipeline) do |job, task|
          return task if task["task"] == task_name && job["name"] == job_name
        end
      end
      nil
    end
  end
end
