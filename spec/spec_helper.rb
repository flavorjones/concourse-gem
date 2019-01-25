require "bundler/setup"
require "concourse"

module RspecExampleHelpers
  def in_tmp_dir
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        yield
      end
    end
  end

  def in_assets_dir dirname
    target = File.join("spec", "assets", dirname)
    Dir.chdir(target) do
      yield
    end
  end

  def shush_stdout &block
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout = old_stdout
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include RspecExampleHelpers
end
