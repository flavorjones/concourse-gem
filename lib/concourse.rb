require "concourse/version"

class Concourse
  include Rake::DSL

  # these numbers/names align with public docker image names
  RUBIES = {
    mri:   %w[2.1 2.2 2.3 2.4], # docker repository: "ruby"
    jruby: %w[1.7 9.1],         # docker repository: "jruby"
    rbx:   %w[latest],          # docker repository: "rubinius/docker"
  }

  DIRECTORY = "concourse"
  PRIVATE_VAR_FILE = File.join DIRECTORY, "private.yml"

  attr_reader :project_name, :pipeline_filename, :pipeline_erb_filename

  def self.validate_fly_target task, task_args
    unless task_args[:fly_target]
      raise "ERROR: must specify a fly target, like `rake #{task.name}[targetname]`"
    end
    return task_args[:fly_target]
  end

  def self.url_for fly_target
    matching_line = `fly targets`.split("\n").grep(/^#{fly_target}/).first
    raise "invalid fly target #{fly_target}" unless matching_line
    matching_line.split(/ +/)[1]
  end

  def initialize project_name
    @project_name = project_name
    @pipeline_filename = File.join(DIRECTORY, "#{project_name}.yml")
    @pipeline_erb_filename = "#{pipeline_filename}.erb"
  end

  def create_tasks!
    unless Dir.exist? DIRECTORY
      mkdir_p DIRECTORY
    end

    unless File.exist? pipeline_erb_filename
      raise "ERROR: concourse pipeline template #{pipeline_erb_filename.inspect} does not exist"
    end

    CLOBBER.include pipeline_filename if defined?(CLOBBER)

    namespace :concourse do
      #
      #  pipeline commands
      #
      desc "generate and validate the pipeline file for #{project_name}"
      task "generate" do |t|
        File.open pipeline_filename, "w" do |f|
          f.write ERB.new(File.read(pipeline_erb_filename)).result(binding)
        end
        sh "fly validate-pipeline -c #{pipeline_filename}"
      end

      desc "upload the pipeline file for #{project_name}"
      task "set", [:fly_target] => ["generate"] do |t, args|
        fly_target = Concourse.validate_fly_target t, args
        options = [
          "-p '#{project_name}'",
          "-c '#{pipeline_filename}'",
        ]
        if File.exist? PRIVATE_VAR_FILE
          puts "using #{PRIVATE_VAR_FILE} to resolve template vars"
          options << "-l '#{PRIVATE_VAR_FILE}'"
        end
        sh "fly -t #{fly_target} set-pipeline #{options.join(" ")}"
      end

      %w[expose hide pause unpause].each do |command|
        desc "#{command} the #{project_name} pipeline"
        task "#{command}", [:fly_target] do |t, args|
          fly_target = Concourse.validate_fly_target t, args
          sh "fly -t #{fly_target} #{command}-pipeline -p #{project_name}"
        end
      end

      desc "remove generate pipeline file"
      task "clean" do |t|
        rm_f pipeline_filename
      end

      #
      #  task commands
      #
      desc "list all the available tasks from the #{project_name} pipeline"
      task "tasks" => "generate" do
        tasks = []

        each_task do |job, task|
          tasks << "#{job["name"]}/#{task["task"]}"
        end

        puts "Available Concourse tasks for #{project_name} are:"
        tasks.sort.each { |task| puts " * #{task}" }
      end

      desc "fly execute the specified task"
      task "task", [:fly_target, :job_task, :fly_execute_args] => "generate" do |t, args|
        fly_target = Concourse.validate_fly_target t, args
        job_task = args[:job_task]
        fly_execute_args = args[:fly_execute_args] || "--input=#{project_name}=."

        unless job_task
          raise "ERROR: must specify a task name, like `rake #{t.name}[target,taskname]`"
        end

        concourse_task = find_task job_task
        raise "ERROR: could not find task `#{job_task}`" unless concourse_task

        puts concourse_task.to_yaml
        Tempfile.create do |f|
          f.write concourse_task["config"].to_yaml
          f.close
          sh "fly -t #{fly_target} execute #{fly_execute_args} -c #{f.path} -x"
        end
      end

      #
      #  badge commands
      #
      desc "display a list of jobs and badge urls"
      task "badges", [:fly_target, :team_name] => "generate" do |t, args|
        fly_target = Concourse.validate_fly_target t, args
        team_name = args[:team_name] || "main"
        url_prefix = Concourse.url_for fly_target

        puts ""
        puts "| Build | Status |"
        puts "|--|--|"

        each_job do |job|
          job_name = job["name"]
          badge_url = badge_url_for url_prefix, team_name, job_name
          job_url = job_url_for url_prefix, team_name, job_name

          puts %Q'| #{titleize job_name} | [![name](#{badge_url})](#{job_url}) |'
        end
      end
    end
  end

  def each_job
    pipeline = YAML.load_file(pipeline_filename)

    pipeline["jobs"].each do |job|
      yield job
    end
  end

  def each_task
    each_job do |job|
      job["plan"].each do |task|
        yield job, task if task["task"]
      end
    end
  end

  def find_task job_task
    job_name, task_name = *job_task.split("/")
    each_task do |job, task|
      return task if task["task"] == task_name && job["name"] == job_name
    end
    nil
  end

  def titleize string
    string.gsub(/[^a-zA-Z0-9\.]/, " ")
  end

  def badge_url_for url_prefix, team_name, job_name
    File.join url_prefix,
              "api/v1/teams",
              team_name,
              "pipelines",
              project_name,
              "jobs",
              job_name,
              "badge"
  end

  def job_url_for url_prefix, team_name, job_name
    File.join url_prefix,
              "teams",
              team_name,
              "pipelines",
              project_name,
              "jobs",
              job_name
  end
end
