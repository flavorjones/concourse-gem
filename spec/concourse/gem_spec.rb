require "spec_helper"

RSpec.describe Concourse do
  it "has a version number" do
    expect(Concourse::VERSION).not_to be nil
  end
end
