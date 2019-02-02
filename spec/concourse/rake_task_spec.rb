require "spec_helper"

describe "injected rake tasks" do
  describe "rake tasks" do
    describe "init" do
      let(:concourse) { Concourse.new "myproject", directory: "ci" }

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

    describe "generate" do
      let(:concourse) do
        Concourse.new "myproject" do |c|
          c.add_pipeline "test-require", "test-require.yml"
          c.add_pipeline "test-erbify_file", "test-erbify_file.yml"
        end
      end

      around do |example|
        in_assets_dir("test-project") do
          example.run
        end
      end

      context "a pipeline that uses 'require'" do
        let(:pipeline) { concourse.pipelines.find { |p| p.name == "test-require" } }

        it "finds a file in the pipeline directory and `Kernel.require`s it" do
          shush_stdout do
            concourse.rake_pipeline_generate pipeline
          end

          expect(File.read(pipeline.filename)).to eq(<<~EOYAML)
            digest: 2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae
            result: "The file foo.rb contains a global variable $foo whose value is shamalamadingdong"
          EOYAML
        end

        it "is linted with fly" do
          expect(Rake).to receive(:sh).with("fly -t default validate-pipeline -c #{pipeline.filename}", anything)

          shush_stdout do
            concourse.rake_pipeline_generate pipeline
          end
        end
      end

      context "a pipeline that uses 'erbify_file'" do
        let(:pipeline) { concourse.pipelines.find { |p| p.name == "test-erbify_file" } }

        it "finds the file in the pipeline directory, erbifies it with the current binding, and inlines the result" do
          shush_stdout do
            concourse.rake_pipeline_generate pipeline
          end

          expect(File.read(pipeline.filename)).to eq(<<~EOYAML)
            one: 1
            # a local yaml file, which emits content using $foo
            nested_result: shamalamadingdong
            two: 2
          EOYAML
        end
      end
    end
  end
end
