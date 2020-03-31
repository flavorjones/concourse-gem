require "spec_helper"

describe Concourse do
  describe ".new" do
    describe "#project name" do
      it "requires project name" do
        expect { Concourse.new }.to raise_exception(ArgumentError)
      end

      it "is saved" do
        expect(Concourse.new("myproject").project_name).to eq "myproject"
      end
    end
  end

  describe ".new with a block" do
    it "doesn't create a default pipeline" do
      concourse = Concourse.new("myproject") do
        # do nothing
      end

      expect(concourse.pipelines).to be_empty
    end

    it "it yields self" do
      actual_result = nil
      concourse = Concourse.new("myproject") do |object|
        actual_result = object
      end

      expect(concourse).to eq(actual_result)
    end
  end

  describe "#directory" do
    it "defaults to 'concourse'" do
      expect(Concourse.new("myproject").directory).to eq "concourse"
    end

    it "optionally accepts a directory name" do
      concourse = Concourse.new("myproject", directory: "ci")
      expect(concourse.directory).to eq("ci")
    end
  end

  describe "#fly_target" do
    it "defaults to 'default'" do
      expect(Concourse.new("myproject").fly_target).to eq "default"
    end

    it "optionally accepts a fly_target name" do
      expect(Concourse.new("myproject", fly_target: "myci").fly_target).to eq "myci"
    end
  end

  describe "#format" do
    it "default to false'" do
      expect(Concourse.new("myproject").format).to be_falsey
    end

    it "optionally accepts a format boolean" do
      expect(Concourse.new("myproject", format: true).format).to eq(true)
      expect(Concourse.new("myproject", format: false).format).to eq(false)
    end
  end

  describe "#pipelines" do
    context "by default" do
      it "has one pipeline named after the project name" do
        concourse = Concourse.new("myproject")
        expect(concourse.pipelines.length).to eq(1)
        expect(concourse.pipelines.first.name).to eq("myproject")
        expect(concourse.pipelines.first.erb_filename).to eq("concourse/myproject.yml")
        expect(concourse.pipelines.first.filename).to eq("concourse/myproject.yml.generated")
      end
    end
  end

  describe "#secrets_filename" do
    it "is `private.yml` by default" do
      expect(Concourse.new("myproject").secrets_filename).to eq("concourse/private.yml")
    end

    it "can be set" do
      expect(Concourse.new("myproject", secrets_filename: "secrets.yml").secrets_filename).to eq("concourse/secrets.yml")
    end
  end

  describe "#add_pipeline" do
    it "requires name and filename arguments" do
      expect { Concourse.new("myproject").add_pipeline("a") }.to raise_exception(ArgumentError)
    end

    it "creates a Pipeline and adds it to the #pipelines array" do
      concourse = Concourse.new("myproject") do |c|
        c.add_pipeline "foo", "fizzle.yml"
        c.add_pipeline "bar", "fozzle.yml"
      end

      expect(concourse.pipelines.length).to eq(2)
      concourse.pipelines.first.tap do |pipeline|
        expect(pipeline.name).to eq("foo")
        expect(pipeline.directory).to eq(concourse.directory)
        expect(pipeline.erb_filename). to eq("concourse/fizzle.yml")
      end
      concourse.pipelines.last.tap do |pipeline|
        expect(pipeline.name).to eq("bar")
        expect(pipeline.directory).to eq(concourse.directory)
        expect(pipeline.erb_filename). to eq("concourse/fozzle.yml")
      end
    end
  end
end
