require "spec_helper"

RSpec.describe Concourse do
  describe ".new" do
    describe "#project name" do
      it "requires project name" do
        expect { Concourse.new }.to raise_exception(ArgumentError)
      end

      it "uses project name to name the pipeline file" do
        concourse = Concourse.new("myproject")
        expect(concourse.project_name).to eq "myproject"
        expect(concourse.pipeline_filename).to eq "concourse/myproject.yml.generated"
        expect(concourse.pipeline_erb_filename).to eq "concourse/myproject.yml"
      end
    end

    describe "#directory" do
      it "defaults to 'concourse'" do
        expect(Concourse.new("myproject").directory).to eq "concourse"
      end

      it "optionally accepts a directory name" do
        expect(Concourse.new("myproject", directory: "ci").directory).to eq "ci"
      end
    end

    describe "fly_target" do
      it "defaults to 'default'" do
        expect(Concourse.new("myproject").fly_target).to eq "default"
      end

      it "optionally accepts a fly_target name" do
        expect(Concourse.new("myproject", fly_target: "myci").fly_target).to eq "myci"
      end
    end
  end

  def in_tmp_dir &block
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        yield
      end
    end
  end

  def shush_stdout &block
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout = old_stdout
  end

  describe "rake tasks" do
    let(:concourse) { Concourse.new "myproject", directory: "ci" }

    describe "init" do
      it "creates directory and empty pipeline" do
        in_tmp_dir do
          shush_stdout do
            concourse.rake_init
          end

          expect(Dir.exist?("ci/tasks")).to be_truthy
          expect(File.exist?("ci/myproject.yml")).to be_truthy
        end
      end

      it "adds sensitive files to .gitignore" do
        in_tmp_dir do
          shush_stdout do
            concourse.rake_init
          end

          gitignore = File.read(".gitignore").split("\n")
          expect(gitignore).to include("ci/myproject.yml.generated")
          expect(gitignore).to include("ci/private.yml")
        end
      end
    end
  end
end
