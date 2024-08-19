# frozen_string_literal: true
require "tmpdir"
require "fileutils"
require "stringio"
require_relative "../lib/debendencies"

RSpec.describe Debendencies do
  let(:debendencies) { Debendencies.new }
  let(:architecture) { "loongson64" }

  def mock_elf_file(basename, soname: nil, dependencies: [], symbols: [], expecting_symbol_analysis: true)
    path = File.join(@tmpdir, basename)
    File.write(path, Debendencies::Private::ELF_MAGIC, binmode: true)
    File.chmod(0755, path)

    objdump_output = StringIO.new
    objdump_output.write("  SONAME #{soname}\n") if soname
    dependencies.each do |dependency|
      objdump_output.write("  NEEDED #{dependency}\n")
    end
    objdump_output.rewind

    expect(Debendencies::Private).to \
      receive(:popen).
        with(["objdump", "-p", path], anything).
        and_yield(objdump_output)

    nm_output = StringIO.new
    nm_output.write("  SONAME #{soname}\n") if soname
    symbols.each do |symbol|
      nm_output.write("00000000000b6c90 U #{symbol}\n")
    end
    nm_output.rewind

    if expecting_symbol_analysis
      expect(Debendencies::Private).to \
        receive(:popen).
          with(["nm", "-D", path], anything).
          and_yield(nm_output)
    else
      expect(Debendencies::Private).not_to \
        receive(:popen).
          with(["nm", "-D", path], anything)
    end
  end

  def mock_dependency_library(package_name, soname, symbols_and_package_versions = [], expecting_package_lookup: true)
    symbols_file_path = File.join(@tmpdir, "#{package_name}:#{architecture}.symbols")
    File.open(symbols_file_path, mode: "a") do |f|
      f.write("#{soname} #{package_name} #MINVER#\n")
      symbols_and_package_versions.each do |symbol, package_version|
        f.write(" #{symbol} #{package_version}\n")
      end
    end

    if expecting_package_lookup
      expect(Open3).to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}").
          and_return(["#{package_name}:#{architecture}: /somewhere\n", "", double(success?: true)])
    else
      expect(Open3).not_to \
        receive(:capture3).
          with("dpkg-query", "-S", "*/#{soname}")
    end
  end

  describe "#scan and #resolve" do
    before do
      @tmpdir = Dir.mktmpdir
      expect(Debendencies::Private).to receive(:symbols_dir).at_least(:once).and_return(@tmpdir)
      expect(Debendencies::Private).to receive(:dpkg_architecture).at_least(:once).and_return(architecture)
    end

    after do
      FileUtils.remove_entry(@tmpdir)
    end

    let(:dependent_lib_soname) { "libdependent.so.1" }
    let(:dependency_soname1) { "libdependency1.so" }
    let(:dependency_soname2) { "libdependency2.so" }
    let(:dependency_soname3) { "libdependency3.so" }
    let(:package_name1) { "package1" }
    let(:package_name2) { "package2" }

    specify "three dependency libraries over two packages, all with version constraints" do
      mock_elf_file("exe",
                    dependencies: [dependency_soname1],
                    symbols: ["dependency1-A", "dependency1-B"])
      mock_elf_file(dependent_lib_soname,
                    soname: dependent_lib_soname,
                    dependencies: [dependency_soname2, dependency_soname3],
                    symbols: ["dependency2-A", "dependency2-B", "dependency3-B"])
      mock_dependency_library(package_name1, dependency_soname1, [
        ["dependency1-A", "1.0"],
        ["dependency1-B", "2.0"],
        ["dependency1-C", "3.0"],
      ])
      mock_dependency_library(package_name1, dependency_soname2, [
        ["dependency2-A", "1.0"],
        ["dependency2-B", "5.0"],
        ["dependency2-C", "8.0"],
      ])
      mock_dependency_library(package_name2, dependency_soname3, [
        ["dependency3-A", "1.1"],
        ["dependency3-B", "2.1"],
        ["dependency3-C", "3.1"],
      ])

      debendencies.scan(@tmpdir)
      result = debendencies.resolve

      expect(result).to eq([
        Debendencies::PackageDependency.new(package_name1,
                                            [Debendencies::VersionConstraint.new(">=", "2.0")]),
        Debendencies::PackageDependency.new(package_name1,
                                            [Debendencies::VersionConstraint.new(">=", "5.0")]),
        Debendencies::PackageDependency.new(package_name2,
                                            [Debendencies::VersionConstraint.new(">=", "2.1")]),
      ])
    end

    specify "no version constraint" do
      mock_elf_file("exe",
                    dependencies: [dependency_soname1],
                    symbols: ["mysymbol"])
      mock_dependency_library(package_name1, dependency_soname1, [
        ["dependency1-A", "1.0"],
        ["dependency1-B", "2.0"],
        ["dependency1-C", "3.0"],
      ])

      debendencies.scan(@tmpdir)
      result = debendencies.resolve

      expect(result).to eq([
        Debendencies::PackageDependency.new(package_name1),
      ])
    end

    it "does not output a dependency on a scanned library" do
      mock_elf_file(dependent_lib_soname,
                    soname: dependent_lib_soname,
                    dependencies: [dependency_soname1, dependency_soname2])
      mock_elf_file(dependency_soname1,
                    soname: dependency_soname1,
                    expecting_symbol_analysis: false)
      mock_dependency_library(package_name1, dependency_soname1, expecting_package_lookup: false)
      mock_dependency_library(package_name2, dependency_soname2)

      debendencies.scan(@tmpdir)
      result = debendencies.resolve

      expect(result).to eq([
        Debendencies::PackageDependency.new(package_name2),
      ])
    end
  end
end
