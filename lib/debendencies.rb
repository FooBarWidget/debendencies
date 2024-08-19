require "set"
require_relative "debendencies/elf_analysis"
require_relative "debendencies/package_finding"
require_relative "debendencies/errors"
require_relative "debendencies/utils"

class Debendencies
  # Represents a single Debian package dependency, e.g., `libc`.
  # Could potentially have version constraints, e.g., `libc (>= 2.28, <= 2.30)`.
  #
  # `version_constraints` is either nil or non-empty.
  class PackageDependency
    attr_reader :name, :version_constraints

    def initialize(name, version_constraints = nil)
      @name = name
      @version_constraints = version_constraints
    end

    def eql?(other)
      @name == other.name && @version_constraints == other.version_constraints
    end

    alias_method :==, :eql?

    def hash
      @name.hash ^ @version_constraints.hash
    end

    def to_s
      if version_constraints.nil?
        name
      else
        "#{name} (#{version_constraints.map.join(", ")})"
      end
    end
  end

  # Represents a version constraint, e.g., `>= 2.28`.
  class VersionConstraint
    attr_reader :operator, :version

    def initialize(operator, version)
      @operator = operator
      @version = version
    end

    def eql?(other)
      @operator == other.operator && @version == other.version
    end

    alias_method :==, :eql?

    def hash
      @operator.hash ^ @version.hash
    end

    def to_s
      "#{operator} #{version}"
    end
  end

  def initialize
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
      next if @scanned_libs.include?(dependency_soname)

      package_name = Private.find_package_providing_lib(dependency_soname)
      raise Error, "Error resolving package dependencies: no package provides #{dependency_soname}" if package_name.nil?
      version_constraints = maybe_create_version_constraints(package_name, dependency_soname, dependent_elf_file_paths)

      result << PackageDependency.new(package_name, version_constraints)
    end

    result.uniq!
    result
  end

  private

  def scan_directory(dir)
    Dir.glob("**/*", base: dir) do |entry|
      path = File.join(dir, entry)
      scan_file(path) if File.file?(path) && File.executable?(path)
    end
  end

  def scan_file(path)
    # Libraries tend to have multiple symlinks (e.g. libfoo.so -> libfoo.so.1 -> libfoo.so.1.2.3)
    # and we only want to process libraries once, so ignore symlinks.
    return if !Private.elf_file?(path) || File.symlink?(path)

    soname, dependency_libs = Private.extract_soname_and_dependency_libs(path)
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
