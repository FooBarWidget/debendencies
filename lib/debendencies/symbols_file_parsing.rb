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

require_relative "package_version"

class Debendencies
  module Private
    class << self
      # Parses a symbols file. Yields:
      #
      # - All symbols for the specified library soname.
      # - The package version that provides that symbol.
      #
      # For example, it yields `["fopen@GLIBC_1.0", "5"]`.
      #
      # @param path [String] Path to the symbols file.
      # @param soname [String] Soname of the library to yield symbols for.
      # @yield [String, PackageVersion]
      def list_symbols(path, soname)
        File.open(path, "r:utf-8") do |f|
          # Skips lines in the symbols file until we encounter the start of the section for the given library
          f.each_line do |line|
            break if line.start_with?("#{soname} ")
          end

          f.each_line do |line|
            # Ignore alternative package specifiers and metadata fields like these:
            #
            #   | libtinfo6 #MINVER#, libtinfo6 (<< 6.2~)
            #   * Build-Depends-Package: libncurses-dev
            next if line =~ /^\s*[\|\*]/

            # We look for a line like this:
            #
            #  NCURSES6_TIC_5.0.19991023@NCURSES6_TIC_5.0.19991023 6.1
            #
            # Stop when we reach the section for next library
            break if line !~ /^\s+(\S+)\s+(\S+)/

            raw_symbol = $1
            package_version_string = $2
            yield [raw_symbol.sub(/@Base$/, ""), PackageVersion.new(package_version_string)]
          end
        end
      end

      def find_symbols_file(package_name, architecture)
        path = File.join(symbols_dir, "#{package_name}:#{architecture}.symbols")
        path if File.exist?(path)
      end

      private

      # Mocked during tests.
      def symbols_dir
        "/var/lib/dpkg/info"
      end
    end
  end
end
