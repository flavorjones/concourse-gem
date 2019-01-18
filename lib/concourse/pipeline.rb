class Concourse
  class Pipeline
    attr_reader :directory, :erb_filename, :filename

    def initialize directory, erb_filename
      @directory = directory
      @erb_filename = File.join(@directory, erb_filename)
      @filename = File.join(@directory, erb_filename + ".generated")
    end
  end
end
