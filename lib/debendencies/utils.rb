# frozen_string_literal: true
require_relative "errors"

class Debendencies
  module Private
    class << self
      def elf_file?(path)
        File.open(path, "rb") do |f|
          f.read(4) == "\x7FELF".force_encoding("binary")
        end
      end

      def path_resembles_library?(path)
        !!(path =~ /\.so($|\.\d+)/)
      end

      # Runs a command and yields its standard output as an IO object.
      # Like IO.popen but with better error handling.
      # On success, returns the result of the block, otherwise raises an Error.
      def popen(command_args, spawn_error_message:, fail_error_message:)
        begin
          begin
            io = IO.popen(command_args)
          rescue SystemCallError => e
            raise Error, "#{spawn_error_message}: #{e}"
          end

          result = yield io
        ensure
          io.close if io
        end

        if $?.success?
          result
        else
          raise Error, "#{fail_error_message}: #{$?}"
        end
      end

      # Compares two version strings
      def version_compare(v1, v2)
        Gem::Version.new(v1) <=> Gem::Version.new(v2)
      end
    end
  end
end
