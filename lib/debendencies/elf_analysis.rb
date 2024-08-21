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

require "set"
require_relative "errors"
require_relative "utils"

class Debendencies
  module Private
    class << self
      # Extracts from an ELF file using `objdump`:
      #
      # - The ELF file's own soname, if possible. Can be nil.
      # - The list of shared library dependencies (sonames).
      #
      # @param path [String] Path to the ELF file to analyze.
      # @return [String, Array<Array<String>>]
      # @raise [Error] If `objdump` fails.
      def extract_soname_and_dependency_libs(path)
        popen(["objdump", "-p", path],
              spawn_error_message: "Error scanning ELF file dependencies: cannot spawn 'objdump'",
              fail_error_message: "Error scanning ELF file dependencies: 'objdump' failed") do |io|
          soname = nil
          dependent_libs = []

          io.each_line do |line|
            case line
            when /^\s*SONAME\s+(.+)$/
              soname = $1.strip
            when /^\s*NEEDED\s+(.+)$/
              dependent_libs << $1.strip
            end
          end

          [soname, dependent_libs]
        end
      end

      # Extracts dynamic symbols from ELF files using `nm`.
      #
      # @param paths [Array<String>] Paths to the ELF files to analyze.
      # @param cache [Hash<String, Set<String>>]
      # @return [Set<String>] Set of dynamic symbols.
      # @raise [Error] If `nm` fails.
      def extract_dynamic_symbols(paths, cache = {})
        result = Set.new

        paths.each do |path|
          subresult = cache[path] ||=
            popen(["nm", "-D", path],
                  spawn_error_message: "Error extracting dynamic symbols from #{path}: cannot spawn 'nm'",
                  fail_error_message: "Error extracting dynamic symbols from #{path}: 'nm' failed") do |io|
              io.each_line.lazy.map do |line|
                # Line is in the following format:
                #
                #                  U waitpid
                # 0000000000126190 B want_pending_command
                #                    ^^^^^^^^^^^^^^^^^^^^
                #                    we want to extract this
                $1 if line =~ /^\S*\s+[A-Za-z]\s+(.+)/
              end.compact.to_set
            end
          result.merge(subresult)
        end

        result
      end
    end
  end
end
