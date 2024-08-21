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

require "tempfile"
require_relative "../lib/debendencies/symbols_file_parsing"

RSpec.describe Debendencies::Private do
  describe ".list_symbols" do
    let(:soname) { "libfoo.so.1" }
    let(:soname2) { "libfoo.so.2" }
    let(:soname3) { "libfoo.so.3" }
    let(:package_name) { "libfoo1" }

    it "yields symbols and versions for the given library section" do
      symbols_file_content = <<~CONTENT
        #{soname} #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol1@Base 1.0
         symbol2@foo 2.0
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        result = []
        described_class.list_symbols(symbols_file.path, soname) do |symbol, version|
          result << [symbol, version.to_s]
        end

        expect(result).to eq([["symbol1", "1.0"], ["symbol2@foo", "2.0"]])
      end
    end

    it "ignores non-indented alternative package specifiers and metadata fields" do
      symbols_file_content = <<~CONTENT
        #{soname} #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol1 1.0
         symbol2 2.0
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        result = []
        described_class.list_symbols(symbols_file.path, soname) do |symbol, version|
          result << [symbol, version.to_s]
        end

        expect(result).to eq([["symbol1", "1.0"], ["symbol2", "2.0"]])
      end
    end

    it "ignores indented alternative package specifiers and metadata fields" do
      symbols_file_content = <<~CONTENT
        #{soname} #{package_name} #MINVER#
         | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
         * Build-Depends-Package: libncurses-dev
         symbol1 1.0
         symbol2 2.0
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        result = []
        described_class.list_symbols(symbols_file.path, soname) do |symbol, version|
          result << [symbol, version.to_s]
        end

        expect(result).to eq([["symbol1", "1.0"], ["symbol2", "2.0"]])
      end
    end

    it "only considers the section belonging to the requested soname" do
      symbols_file_content = <<~CONTENT
        #{soname2} #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev  
         symbol1 1.0
         symbol2 2.0
        #{soname} #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol3 1.0
         symbol4 2.0
        #{soname3} #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol5 3.0
         symbol6 3.0
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        result = []
        described_class.list_symbols(symbols_file.path, soname) do |symbol, version|
          result << [symbol, version.to_s]
        end

        expect(result).to eq([["symbol3", "1.0"], ["symbol4", "2.0"]])
      end
    end
  end
end
