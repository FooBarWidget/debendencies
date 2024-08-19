# frozen_string_literal: true
require "set"
require_relative "debendencies/elf_analysis"
require_relative "debendencies/package_finding"
require_relative "debendencies/package_dependency"
require_relative "debendencies/errors"
require_relative "debendencies/utils"

class Debendencies
  def initialize(logger: nil)
    @logger = logger

    # Shared libraries (sonames) that have been scanned.
    @scanned_libs = Set.new

    # Shared libraries (sonames) that the scanned ELF files depend on.
    # Maps each soname to an array of ELF file path that depend on it (the dependents).
    @dependency_libs = {}

    @symbol_extraction_cache = {}
  end

  def scan(*paths)
    paths.each do |path|
      if File.directory?(path)
        scan_directory(path)
      else
        scan_file(path)
      end
    end
  end

  # Resolves the Debian package dependencies of all scanned ELF files.
  # Returns an array of PackageDependency objects:
  #
  #   [
  #     PackageDependency.new('libc6', [VersionConstraint.new('>=', '2.28')]),
  #     PackageDependency.new('libfoo1'),
  #   ]
  #
  # @return [Array<PackageDependency>]
  def resolve
    result = []

    @dependency_libs.each_pair do |dependency_soname, dependent_elf_file_paths|
      # ELF files in a package could depend on libraries included in the same package,
      # so omit resolving scanned libraries.
      if @scanned_libs.include?(dependency_soname)
        @logger&.info("Skipping dependency resolution for scanned library: #{dependency_soname}")
        next
      end

      package_name = Private.find_package_providing_lib(dependency_soname)
      raise Error, "Error resolving package dependencies: no package provides #{dependency_soname}" if package_name.nil?
      @logger&.info("Resolved package providing #{dependency_soname}: #{package_name}")
      version_constraints = maybe_create_version_constraints(package_name, dependency_soname, dependent_elf_file_paths)
      @logger&.info("Resolved version constraints: #{version_constraints.as_json.inspect}")

      result << PackageDependency.new(package_name, version_constraints)
    end

    result.uniq!
    result
  end

  private

  def scan_directory(dir)
    Dir.glob("**/*", base: dir) do |entry|
      path = File.join(dir, entry)

      if File.symlink?(path)
        # Libraries tend to have multiple symlinks (e.g. libfoo.so -> libfoo.so.1 -> libfoo.so.1.2.3)
        # and we only want to process libraries once, so ignore symlinks.
        @logger&.warn("Skipping symlink: #{path}")
        next
      end

      scan_file(path) if File.file?(path) && File.executable?(path)
    end
  end

  def scan_file(path)
    @logger&.info("Scanning ELF file: #{path}")
    return @logger&.warn("Skipping non-ELF file: #{path}") if !Private.elf_file?(path)

    soname, dependency_libs = Private.extract_soname_and_dependency_libs(path)
    @logger&.info("Detected soname: #{soname || "(none)"}")
    @logger&.info("Detected dependencies: #{dependency_libs.inspect}")
    if Private.path_resembles_library?(path) && soname.nil?
      raise Error, "Error scanning ELF file: cannot determine shared library name (soname) for #{path}"
    end

    @scanned_libs << soname if soname
    dependency_libs.each do |dependency_soname|
      dependents = (@dependency_libs[dependency_soname] ||= [])
      dependents << path
    end
  end

  def maybe_create_version_constraints(package_name, soname, dependent_elf_files)
    symbols_file_path = Private.find_symbols_file(package_name, Private.dpkg_architecture)
    if symbols_file_path
      min_version = Private.find_min_package_version(soname,
                                                     symbols_file_path,
                                                     dependent_elf_files,
                                                     @symbol_extraction_cache)
      [VersionConstraint.new(">=", min_version)] if min_version
    end
  end
end
