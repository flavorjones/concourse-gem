require "concourse/version"

class Concourse
  include Rake::DSL

  # these numbers/names align with public docker image names
  RUBIES = {
    mri:   %w[2.1 2.2 2.3 2.4], # docker repository: "ruby"
    jruby: %w[1.7 9.1], # docker repository: "jruby"
    rbx:   %w[latest], # docker repository: "rubinius/docker"
  }

  DIRECTORY = "concourse"

  attr_reader :project_name

  def self.validate_fly_target task, task_args
    unless task_args[:fly_target]
      raise "must specify a fly target, like `rake #{task.name}[targetname]`"
    end
    return task_args[:fly_target]
  end

  def initialize project_name
    @project_name = project_name
  end

  def create_tasks!
    unless Dir.exist? DIRECTORY
      mkdir_p DIRECTORY
    end

    pipeline_filename = File.join(DIRECTORY, "#{project_name}.yml")
    pipeline_erb_filename = "#{pipeline_filename}.erb"
    unless File.exist? pipeline_erb_filename
      raise "ERROR: concourse pipeline template #{pipeline_erb_filename.inspect} does not exist"
    end

    CLOBBER.include pipeline_filename

    namespace :concourse do
      file pipeline_filename do
        File.open pipeline_filename, "w" do |f|
          f.write ERB.new(File.read(pipeline_erb_filename)).result(binding)
        end
      end

      desc "generate the pipeline file for #{project_name}"
      task "generate" => pipeline_filename do |t|
        sh "fly validate-pipeline -c #{pipeline_filename}"
      end

      desc "upload the pipeline file for #{project_name}"
      task "set", [:fly_target] => ["generate"] do |t, args|
        fly_target = Concourse.validate_fly_target t, args
        sh "fly -t #{fly_target} set-pipeline -p #{project_name} -c #{pipeline_filename}"
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
    end
  end
end
