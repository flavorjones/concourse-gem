require "spec_helper"

describe "injected rake tasks" do
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
