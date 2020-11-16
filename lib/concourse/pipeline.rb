class Concourse
  class Pipeline
    include Concourse::Util

    attr_reader :name, :directory, :erb_filename, :filename, :ytt

    def initialize name, directory, erb_filename, options={}
      @name = name
      @directory = directory
      @erb_filename = File.join(@directory, erb_filename)
      @filename = File.join(@directory, erb_filename + ".generated")
      @ytt = options.key?(:ytt) ? options[:ytt] : false
    end

    def generate
      Tempfile.create(["pipeline", ".yml"]) do |f|
        f.write erbify_file(erb_filename, working_directory: directory)
        f.close

        if ytt
          ytt_args = ["-f #{f.path}"]
          ytt_args.prepend("-f #{File.join(directory, ytt)}") if ytt.is_a?(String)
          sh ["ytt", ytt_args, "> #{filename}"].flatten.join(" ")
        else
          FileUtils.mv f.path, filename, force: true
        end
      end
    end
  end
end
