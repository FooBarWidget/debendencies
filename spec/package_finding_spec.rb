require_relative "../lib/debendencies/package_finding"

RSpec.describe Debendencies::Private do
  describe ".find_package_providing_lib" do
    let(:soname) { "libfoo.so.1" }

    it "returns a package name when found" do
      output = <<~OUTPUT
        libfoo1: /usr/lib/x86_64-linux-gnu/libfoo.so.1
      OUTPUT
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return([output, "", double(success?: true)])

      result = described_class.find_package_providing_lib(soname, "amd64")
      expect(result).to eq("libfoo1")
    end

    it "strips architecture identifiers" do
      output = <<~OUTPUT
        libfoo1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
      OUTPUT
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return([output, "", double(success?: true)])

      result = described_class.find_package_providing_lib(soname, "amd64")
      expect(result).to eq("libfoo1")
    end

    it "returns nil when no packages are found" do
      error_output = "dpkg-query: no path found matching pattern */#{soname}"
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return(["", error_output, double(success?: false, signaled?: false)])

      result = described_class.find_package_providing_lib(soname, "amd64")
      expect(result).to eq(nil)
    end

    it "raises an error when dpkg-query fails" do
      error_output = "some error"
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return(["", error_output, double(success?: false, signaled?: false)])

      expect {
        described_class.find_package_providing_lib(soname, "amd64")
      }.to raise_error(Debendencies::Error,
                       "Error finding packages that provide #{soname}: 'dpkg-query' failed: #{double}: #{error_output.chomp}")
    end

    it "returns the package belonging to the current architecture if multiple packages are found" do
      output = <<~OUTPUT
        libfoo1-i386: /usr/lib/i386-linux-gnu/libfoo.so.1
        libfoo1-i686:i686: /usr/lib/i686-linux-gnu/libfoo.so.1
        libfoo1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
        libfoo1-arm64:arm64: /usr/lib/arm64-linux-gnu/libfoo.so.1
      OUTPUT
      allow(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return([output, "", double(success?: true)])

      result = described_class.find_package_providing_lib(soname, "amd64")
      expect(result).to eq("libfoo1")
    end
  end

  describe ".find_min_package_version" do
    let(:soname) { "libfoo1.so.1" }
    let(:package_name) { "libfoo1" }
    let(:symbols_file_path) { "path/to/symbols_file" }
    let(:elf_file_path) { "path/to/elf_file" }

    it "returns the minimum package version that provides the necessary symbols" do
      dependent_symbols = ["symbol1", "symbol2"]
      symbols = [
        ["symbol1", Debendencies::Private::PackageVersion.new("1.0")],
        ["symbol2", Debendencies::Private::PackageVersion.new("2.0")],
        ["symbol3", Debendencies::Private::PackageVersion.new("3.0")],
      ]

      allow(described_class).to \
        receive(:extract_dynamic_symbols).
          with([elf_file_path], {}).
          and_return(dependent_symbols.to_set)

      allow(described_class).to \
        receive(:list_symbols).
          with(symbols_file_path, soname).
          and_yield(*symbols[0]).
          and_yield(*symbols[1]).
          and_yield(*symbols[2])

      result = described_class.find_min_package_version(soname, symbols_file_path, [elf_file_path])
      expect(result.to_s).to eq("2.0")
    end

    it "returns nil when no symbols in the library are used" do
      dependent_symbols = ["symbol4"]
      symbols = [
        ["symbol1", Debendencies::Private::PackageVersion.new("1.0")],
        ["symbol2", Debendencies::Private::PackageVersion.new("2.0")],
        ["symbol3", Debendencies::Private::PackageVersion.new("3.0")],
      ]

      allow(described_class).to \
        receive(:extract_dynamic_symbols).
          with([elf_file_path], {}).
          and_return(dependent_symbols.to_set)

      allow(described_class).to \
        receive(:list_symbols).
          with(symbols_file_path, soname).
          and_yield(*symbols[0]).
          and_yield(*symbols[1]).
          and_yield(*symbols[2])

      result = described_class.find_min_package_version(soname, symbols_file_path, [elf_file_path])
      expect(result).to be_nil
    end
  end
end
