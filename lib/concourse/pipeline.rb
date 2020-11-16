class Concourse
  class Pipeline
    include Concourse::Util

    attr_reader :name, :directory, :erb_filename, :filename

    def initialize name, directory, erb_filename
      @name = name
      @directory = directory
      @erb_filename = File.join(@directory, erb_filename)
      @filename = File.join(@directory, erb_filename + ".generated")
    end

    def generate
      File.open filename, "w" do |f|
        f.write erbify_file(erb_filename, working_directory: directory)
      end
    end
  end
end
