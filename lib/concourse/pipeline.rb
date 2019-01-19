class Concourse
  class Pipeline
    attr_reader :name, :directory, :erb_filename, :filename

    def initialize name, directory, erb_filename
      @name = name
      @directory = directory
      @erb_filename = File.join(@directory, erb_filename)
      @filename = File.join(@directory, erb_filename + ".generated")
    end
  end
end
