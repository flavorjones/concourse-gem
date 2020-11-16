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
          expect(gitignore).to include("ci/private.yml")
        end
      end
    end

    describe "generate" do
      let(:concourse_options) { Hash.new }

      let(:concourse) do
        Concourse.new "myproject", concourse_options do |c|
          c.add_pipeline "test-require", "test-require.yml"
          c.add_pipeline "test-erbify_file", "test-erbify_file.yml"
          c.add_pipeline "test-ytt", "test-ytt.yml", ytt: true
          c.add_pipeline "test-ytt-with-config", "test-ytt-with-config.yml", ytt: "yttconfig"
          c.add_pipeline "test-erb-and-ytt", "test-erb-and-ytt.yml", ytt: "yttconfig"
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

          expect(File.read(pipeline.filename)).to(eq(<<~EOYAML))
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

        context "'format' is true" do
          let(:concourse_options) { { format: true } }

          it "is formatted with fly" do
            expect(Rake).to receive(:sh).with(match(/^fly.*validate-pipeline.*/), anything)
            expect(Rake).to receive(:sh).with("fly -t default format-pipeline -c #{pipeline.filename} -w", anything)

            shush_stdout do
              concourse.rake_pipeline_generate pipeline
            end
          end
        end
      end

      context "a pipeline that uses 'erbify_file'" do
        let(:pipeline) { concourse.pipelines.find { |p| p.name == "test-erbify_file" } }

        it "finds the file in the pipeline directory, erbifies it with the current binding, and inlines the result" do
          shush_stdout do
            concourse.rake_pipeline_generate pipeline
          end

          expect(File.read(pipeline.filename)).to(eq(<<~EOYAML))
            one: 1
            # a local yaml file, which emits content using $foo
            nested_result: shamalamadingdong
            two: 2
          EOYAML
        end
      end

      context "a pipeline that uses ytt" do
        let(:pipeline) { concourse.pipelines.find { |p| p.name == "test-ytt" } }

        it "runs the pipeline file through ytt" do
          shush_stdout do
            concourse.rake_pipeline_generate pipeline
          end

          expect(File.read(pipeline.filename)).to(eq(<<~EOYAML))
            version: "42.0"
          EOYAML
        end
      end

      context "a pipeline that uses ytt and a config directory" do
        let(:pipeline) { concourse.pipelines.find { |p| p.name == "test-ytt-with-config" } }

        it "runs the pipeline file through ytt using the config directory as an additional input" do
          shush_stdout do
            concourse.rake_pipeline_generate pipeline
          end

          expect(File.read(pipeline.filename)).to(eq(<<~EOYAML))
            version: "42.0"
            injected_name: variable set through config
          EOYAML
        end
      end

      context "a pipeline that uses both ytt and erb, wtfbbq" do
        let(:pipeline) { concourse.pipelines.find { |p| p.name == "test-erb-and-ytt" } }

        it "runs the pipeline file through erb and then ytt" do
          shush_stdout do
            concourse.rake_pipeline_generate pipeline
          end

          expect(File.read(pipeline.filename)).to(eq(<<~EOYAML))
            digest: 2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae
            injected_name: variable set through config
          EOYAML
        end
      end
    end

    describe "local" do
      let(:concourse) { Concourse.new "myproject" }

      before do
        allow(concourse).to receive(:sh).with(anything)
        allow(concourse).to receive(:ensure_docker_compose_file)
      end

      it "sets fly_target to 'local' and logs in" do
        expect(concourse).to receive(:fly).with("login", "-u test -p test -c http://127.0.0.1:8080")
        concourse.rake_concourse_local
        expect(concourse.fly_target).to eq("local")
      end

      it "fetches the concourse-docker quickstart compose file" do
        expect(concourse).to receive(:ensure_docker_compose_file)
        concourse.rake_concourse_local
      end

      describe "local:up" do
        it "fetches the concourse-docker quickstart compose file" do
          expect(concourse).to receive(:ensure_docker_compose_file)
          concourse.rake_concourse_local_up
        end

        it "starts up the local cluster" do
          expect(concourse).to receive(:sh).with("docker-compose -f concourse/docker-compose.yml up -d")
          concourse.rake_concourse_local_up
        end
      end

      describe "local:down" do
        it "fetches the concourse-docker quickstart compose file" do
          expect(concourse).to receive(:ensure_docker_compose_file)
          concourse.rake_concourse_local_down
        end

        it "shuts down the local cluster" do
          expect(concourse).to receive(:sh).with("docker-compose -f concourse/docker-compose.yml down")
          concourse.rake_concourse_local_down
        end
      end
    end
  end
end
