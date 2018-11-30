require "spec_helper"
require 'securerandom'

RSpec.describe Concourse do
  describe ".new" do
    describe "#project name" do
      it "requires project name" do
        expect { Concourse.new }.to raise_exception(ArgumentError)
      end

      it "uses project name to name the pipeline file" do
        concourse = Concourse.new("myproject")
        expect(concourse.project_name).to eq "myproject"
        expect(concourse.pipeline_filename).to eq "concourse/myproject.final.yml"
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

    describe '#pipeline_filename' do
      subject { instance.pipeline_filename }

      let(:instance) { Concourse.new(project_name, args) }
      let(:project_name) { 'myproject' }

      context 'when no pipeline_filename is specified' do
        let(:args) { {} }

        it "defaults to use project_name" do
          expect(subject).to eq "#{instance.directory}/#{project_name}.final.yml"
        end
      end

      context 'when pipeline_filename is specified' do
        let(:args) { {pipeline_filename: pipeline_filename} }
        let(:pipeline_filename) { SecureRandom.hex(12) }

        it 'uses the specified pipeline_filename' do
          expect(subject).to eq "#{instance.directory}/#{pipeline_filename}"
        end
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

  describe "rake tasks" do
    let(:concourse) { Concourse.new "myproject", directory: "ci" }

    describe "init" do
      it "creates directory and empty pipeline" do
        in_tmp_dir do
          concourse.rake_init

          expect(Dir.exist?("ci/tasks")).to be_truthy
          expect(File.exist?("ci/myproject.yml")).to be_truthy
        end
      end

      it "adds sensitive files to .gitignore" do
        in_tmp_dir do
          concourse.rake_init

          gitignore = File.read(".gitignore").split("\n")
          expect(gitignore.grep("ci/myproject.final.yml")).to be_truthy
          expect(gitignore.grep("ci/private.yml")).to be_truthy
        end
      end
    end
  end
end
