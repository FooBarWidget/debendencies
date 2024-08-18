require "open3"
require "set"

class Debendencies
  class Error < StandardError; end

  # `version_constraints` is either nil or non-empty.
  Dependency = Struct.new(:name, :version_constraints)
  VersionConstraint = Struct.new(:operator, :version)

  def initialize
    # Shared libraries (sonames) that have been scanned.
    @scanned_libs = Set.new

    # Shared libraries (sonames) that the scanned ELF files depend on.
    @dependent_libs = Set.new
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

  def resolve
    result = []

    # ELF files in a package could depend on libraries included in the same package,
    # so omit processing scanned libraries.
    (@dependent_libs - @scanned_libs).each do |soname|
      dep = resolve_package_dependency_for(soname)
      result << dep if dep
    end

    result
  end

  private

  def scan_directory(dir)
    Dir.glob("**/*", base: dir).each do |file|
      scan_file(file) if File.file?(file) && File.executable?(file)
    end
  end

  def scan_file(path)
    # Libraries tend to have multiple symlinks (e.g. libfoo.so -> libfoo.so.1 -> libfoo.so.1.2.3)
    # and we only want to process libraries once, so ignore symlinks.
    return if !elf_file?(path) || File.symlink?(path)

    dependent_libs, soname = extract_dependent_libs_and_soname(path)
    @dependent_libs.merge(dependent_libs)
    @scanned_libs << soname if soname
  end

  def elf_file?(path)
    File.open(path, "rb") do |f|
      f.read(4) == "\x7FELF".force_encoding("binary")
    end
  end

  def path_resembles_library?(path)
    path =~ /\.so($|\.\d+)/
  end

  # Extracts from an ELF file the list of shared library dependencies (sonames)
  # and (if possible) also the soname.
  def extract_dependent_libs_and_soname(path)
    popen(["objdump", "-p", path],
          spawn_error_message: "Error scanning ELF file: cannot spawn 'objdump'",
          fail_error_message: "Error scanning ELF file: 'objdump' failed") do |io|
      dependent_libs = []
      soname = nil

      io.each_line do |line|
        case line
        when /^\s*NEEDED\s+(.+)$/
          dependent_libs << $1.strip
        when /^\s*SONAME\s+(.+)$/
          soname = $1.strip
        end
      end

      [dependent_libs.uniq, soname]
    end
  end

  def resolve_package_dependency_for(soname)
    alternative_packages, lib_path = find_alternative_packages_for_lib(soname)
    return if alternative_packages.empty?

    result = alternative_packages.map do |package_name|
      if (symbols_file_path = find_symbols_file(package_name))
        min_version = find_min_package_version(package_name, symbols_file_path, lib_path)
        create_dependency_object(package_name, min_version)
      else
        create_dependency_object(package_name)
      end
    end

    result.size == 1 ? result.first : result
  end

  # Finds all packages providing a specific library soname.
  #
  # @return [Array<String>, String] First element is a list of package names,
  #   possibly including architecture identifier, like "libc6:amd64". Second
  #  element is the full path to the library file.
  def find_alternative_packages_for_lib(soname)
    output, status = Open3.capture2e("dpkg-query", "-S", "*/#{lib}")
    raise Error, "Error finding packages that provide #{soname}: 'dpkg-query' failed: #{status}" unless status.success?

    package_names = []
    result_path = nil

    # Output is in the following format and could contain alternatives:
    # libfoo1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
    # libfoofork1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
    #
    # The architecture could be omitted, like so:
    # libfoo1: /usr/lib/x86_64-linux-gnu/libfoo1.so.1
    output.split("\n").each do |line|
      package_name, path = line.split(/\s*:\s*/, 2)
      package_names << package_name
      result_path ||= path
    end

    [package_names, result_path]
  end

  def find_symbols_file(package_name)
    path = "/var/lib/dpkg/info/#{package_name}.symbols"
    path if File.exist?(path)
  end

  # Find the minimum version of the package that provides the necessary symbols
  def find_min_package_version(package_name, symbols_file_path, elf_file_path)
    dynamic_symbols = extract_dynamic_symbols(elf_file_path)
    return nil if dynamic_symbols.empty?

    max_used_package_version = nil

    File.open(symbols_file_path, "r:utf-8") do |f|
      skip_until_first_symbol_for_package(f, package_name)

      f.each_line do |line|
        # We look for a line like this:
        #
        #  NCURSES6_TIC_5.0.19991023@NCURSES6_TIC_5.0.19991023 6.1
        if line !~ /^\s+([^\s]+)\s+([^\s]+)/
          # Stop when we reach the section for next library
          break
        end

        symbol = $1
        package_version = $2

        if dynamic_symbols.include?(symbol)
          if max_used_package_version.nil? || version_compare(package_version, max_used_package_version) > 0
            max_used_package_version = package_version
          end
        end
      end
    end

    max_used_package_version
  end

  # Extracts dynamic symbols from an ELF file using `nm`
  def extract_dynamic_symbols(path)
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
  end

  # Skip lines in the symbols file until the first symbol for the given package
  def skip_until_first_symbol_for_package(file, package_name)
    file.each_line do |line|
      break if line.starts_with?("#{package_name} ")
    end
  end

  # Compare two version strings
  def version_compare(v1, v2)
    Gem::Version.new(v1) <=> Gem::Version.new(v2)
  end

  # Runs a command and yields its standard output as an IO object.
  # Like IO.popen but with better error handling.
  # On success, returns the result of the block, otherwise raises an Error.
  def popen(command_args, spawn_error_message:, fail_error_message:)
    begin
      io = IO.popen(command_args)
    rescue SystemCallError => e
      raise Error, "#{spawn_error_message}: #{e}"
    end

    begin
      result = yield io
    ensure
      io.close
    end

    if $?.success?
      result
    else
      raise Error, "#{fail_error_message}: #{$?}"
    end
  end

  def create_dependency_object(pkg, min_version = nil)
    if min_version
      version_constraint = VersionConstraint.new(">=", min_version)
      Dependency.new(pkg, [version_constraint])
    else
      Dependency.new(pkg, nil)
    end
  end
end
