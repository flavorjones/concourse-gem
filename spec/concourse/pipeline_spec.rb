require "spec_helper"

describe Concourse::Pipeline do
  describe ".new" do
    it "requires name, directory, and filename arguments" do
      expect { Concourse::Pipeline.new(1, 2) }.to raise_exception(ArgumentError)
    end
  end

  describe "#name" do
    it { expect(Concourse::Pipeline.new("asdf", "qwer", "zxcv").name).to eq("asdf") }
  end

  describe "#directory" do
    it { expect(Concourse::Pipeline.new("asdf", "qwer", "zxcv").directory).to eq("qwer") }
  end

  describe "#filename" do
    it { expect(Concourse::Pipeline.new("asdf", "qwer", "zxcv").erb_filename).to eq("qwer/zxcv") }
    it { expect(Concourse::Pipeline.new("asdf", "qwer", "zxcv").filename).to eq("qwer/zxcv.generated") }
  end
end
