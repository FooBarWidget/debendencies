# frozen_string_literal: true
require "optparse"
require_relative "../debendencies"
require_relative "version"

class Debendable
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
        puts option_parser
        exit 1
      end

      debendencies = Debendencies.new
      begin
        debendencies.scan(*paths)
        dependencies = debendencies.resolve
      rescue Error => e
        abort(e.message)
      end

      case @options[:format]
      when "oneline"
        puts dependencies.map(&:name).join(" ")
      when "text"
        dependencies.each do |dep|
          puts dep.to_s
        end
      when "json"
        puts JSON.pretty_generate(dependencies.as_json)
      else
        puts "Invalid format: #{@options[:format]}"
        exit 1
      end
    end

    private

    def option_parser
      @option_parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: debendencies <PATHS...>"

        opts.on("-f", "--format FORMAT", "Output format (oneline|text|json). Default: oneline") do |format|
          @options[:format] = format
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
  end
end
