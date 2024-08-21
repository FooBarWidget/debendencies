# frozen_string_literal: true
require "optparse"
require_relative "../debendencies"
require_relative "version"

class Debendencies
  class CLI
    def initialize
      @options = {
        format: "oneline",
      }
    end

    def run
      option_parser.parse!
      require "json" if @options[:format] == "json"

      paths = ARGV
      if paths.empty?
        STDERR.puts option_parser
        exit 1
      end

      debendencies = Debendencies.new(logger: get_logger)
      begin
        debendencies.scan(*paths)
        dependencies = debendencies.resolve
      rescue Error => e
        abort(e.message)
      end

      case @options[:format]
      when "oneline"
        write_output(dependencies.map { |d| d.to_s }.join(", "))
      when "multiline"
        write_output(dependencies.map { |d| d.to_s }.join("\n"))
      when "json"
        write_output(JSON.generate(dependencies.map { |d| d.as_json }))
      else
        abort "Invalid format: #{@options[:format]}"
      end
    end

    private

    def option_parser
      @option_parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: debendencies <PATHS...>"

        opts.on("-f", "--format FORMAT", "Output format (oneline|multiline|json). Default: oneline") do |format|
          if !["oneline", "multiline", "json"].include?(format)
            abort "Invalid format: #{format.inspect}"
          end
          @options[:format] = format
        end

        opts.on("-o", "--output PATH", "Write output file instead of standard output") do |path|
          @options[:output] = path
        end

        opts.on("--tee", "When --output is specified, also write to standard output") do
          @options[:tee] = true
        end

        opts.on("--verbose", "Show verbose output") do
          @options[:verbose] = true
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          exit
        end

        opts.on("--version", "Show version") do
          puts VERSION_STRING
          exit
        end
      end
    end

    def write_output(text)
      if @options[:output]
        File.open(@options[:output], "w") do |f|
          f.write(text) unless text.empty?
        end
        puts text if @options[:tee] && !text.empty?
      else
        puts text unless text.empty?
      end
    end

    def get_logger
      if @options[:verbose]
        require "logger"
        Logger.new(STDERR)
      end
    end
  end
end
