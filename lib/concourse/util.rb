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

    def sh command
      running "(in #{Dir.pwd}) #{command}"
      super command, verbose: false
    end

    def running message
      print bold, red, "RUNNING: ", reset, message, "\n"
    end

    def note message
      print bold, green, "NOTE: ", reset, message, "\n"
    end

    def erbify document_string, *args
      ERB.new(document_string, nil, "%-").result(binding)
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
