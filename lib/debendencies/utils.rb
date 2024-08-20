# frozen_string_literal: true
require_relative "errors"

class Debendencies
  module Private
    ELF_MAGIC = String.new("\x7FELF").force_encoding("binary").freeze

    class << self
      def elf_file?(path)
        File.open(path, "rb") do |f|
          f.read(4) == ELF_MAGIC
        end
      end

      def path_resembles_library?(path)
        !!(path =~ /\.so($|\.\d+)/)
      end

      def dpkg_architecture
        read_string_envvar("DEB_HOST_ARCH") ||
          read_string_envvar("DEB_BUILD_ARCH") ||
          @dpkg_architecture ||= begin
              popen(["dpkg", "--print-architecture"],
                    spawn_error_message: "Error getting dpkg architecture: cannot spawn 'dpkg'",
                    fail_error_message: "Error getting dpkg architecture: 'dpkg --print-architecture' failed") do |io|
                io.read.chomp
              end
            end
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

      private

      def read_string_envvar(name)
        value = ENV[name]
        value if value && !value.empty?
      end
    end
  end
end
