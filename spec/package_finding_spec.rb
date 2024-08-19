require "tempfile"
require_relative "../lib/debendencies/package_finding"

RSpec.describe Debendencies::Private do
  describe ".find_packages_providing_lib" do
    let(:soname) { "libfoo.so.1" }

    it "returns package names when packages are found" do
      output = <<~OUTPUT
        libfoo1: /usr/lib/x86_64-linux-gnu/libfoo.so.1
        libfoofork1: /usr/lib/x86_64-linux-gnu/libfoo.so.1
      OUTPUT
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return([output, "", double(success?: true)])

      result = described_class.find_packages_providing_lib(soname)
      expect(result).to eq(["libfoo1", "libfoofork1"])
    end

    it "strips architecture identifiers" do
      output = <<~OUTPUT
        libfoo1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
        libfoofork1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
      OUTPUT
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return([output, "", double(success?: true)])

      result = described_class.find_packages_providing_lib(soname)
      expect(result).to eq(["libfoo1", "libfoofork1"])
    end

    it "returns empty array when no packages are found" do
      error_output = "dpkg-query: no path found matching pattern */#{soname}"
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return(["", error_output, double(success?: false, signaled?: false)])

      result = described_class.find_packages_providing_lib(soname)
      expect(result).to eq([])
    end

    it "raises an error when dpkg-query fails" do
      error_output = "some error"
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return(["", error_output, double(success?: false, signaled?: false)])

      expect {
        described_class.find_packages_providing_lib(soname)
      }.to raise_error(Debendencies::Error,
                       "Error finding packages that provide #{soname}: 'dpkg-query' failed: #{double}: #{error_output.chomp}")
    end
  end

  describe ".find_min_package_version" do
    let(:soname) { "libfoo1.so.1" }
    let(:package_name) { "libfoo1" }
    let(:elf_file_path) { "path/to/elf_file" }

    it "returns the minimum package version that provides the necessary symbols" do
      dynamic_symbols = ["symbol1", "symbol2"]
      symbols_file_content = <<~CONTENT
        #{soname} #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol1 1.0
         symbol2 2.0
         symbol3 3.0
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        allow(described_class).to \
          receive(:extract_dynamic_symbols).
            with([elf_file_path], {}).
            and_return(dynamic_symbols)

        result = described_class.find_min_package_version(soname, symbols_file.path, [elf_file_path])
        expect(result).to eq("2.0")
      end
    end

    it "returns nil when no symbols in the library are used" do
      dynamic_symbols = ["symbol4"]
      symbols_file_content = <<~CONTENT
        #{soname} #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol1 1.0
         symbol2 2.0
         symbol3 3.0
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        allow(described_class).to \
          receive(:extract_dynamic_symbols).
            with([elf_file_path], {}).
            and_return(dynamic_symbols)

        result = described_class.find_min_package_version(soname, symbols_file.path, [elf_file_path])
        expect(result).to be_nil
      end
    end

    it "returns nil when the symbols file has no section for the given library" do
      dynamic_symbols = ["symbol1"]
      symbols_file_content = <<~CONTENT
        libbar.so.1 #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol1 1.0
         symbol2 2.0
         symbol3 3.0
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        allow(described_class).to \
          receive(:extract_dynamic_symbols).
            with([elf_file_path], {}).
            and_return(dynamic_symbols)

        result = described_class.find_min_package_version(soname, symbols_file.path, [elf_file_path])
        expect(result).to be_nil
      end
    end

    it "skips to the right section in the symbols file and doesn't read past that section" do
      dynamic_symbols = ["symbol1", "symbol2"]
      symbols_file_content = <<~CONTENT
        libbar.so.1 #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol1 6.1
         symbol2 6.2
        #{soname} #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol1 1.0
         symbol2 2.0
         symbol3 3.0
        libbaz.so.1 #{package_name} #MINVER#
        | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
        * Build-Depends-Package: libncurses-dev
         symbol1 7.1
         symbol2 7.2
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        allow(described_class).to \
          receive(:extract_dynamic_symbols).
            with([elf_file_path], {}).
            and_return(dynamic_symbols)

        result = described_class.find_min_package_version(soname, symbols_file.path, [elf_file_path])
        expect(result).to eq("2.0")
      end
    end

    it "handles indented package alternatives specifiers and indented metadata" do
      dynamic_symbols = ["symbol1", "symbol2"]
      symbols_file_content = <<~CONTENT
        #{soname} #{package_name} #MINVER#
         | #{package_name} #MINVER#, #{package_name} (<< 6.2~)
         * Build-Depends-Package: libncurses-dev
         symbol1 1.0
         symbol2 2.0
         symbol3 3.0
      CONTENT

      Tempfile.create("symbols_file") do |symbols_file|
        symbols_file.write(symbols_file_content)
        symbols_file.flush

        allow(described_class).to \
          receive(:extract_dynamic_symbols).
            with([elf_file_path], {}).
            and_return(dynamic_symbols)

        result = described_class.find_min_package_version(soname, symbols_file.path, [elf_file_path])
        expect(result).to eq("2.0")
      end
    end
  end
end
