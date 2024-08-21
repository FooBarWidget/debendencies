# frozen_string_literal: true
# Copyright 2024 Hongli Lai
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

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
