require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

desc "update README table of contents"
task :readme_toc => :install_markdown_utils do
  system "node_modules/.bin/markdown-toc -i --maxdepth 3 README.md"
end

task :install_markdown_utils do
  if ! File.exist?("node_modules/.bin/markdown-toc")
    system "npm install markdown-toc"
  end
end
