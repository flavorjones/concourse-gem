require "spec_helper"

describe "injected rake tasks" do
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
