require 'open3'
require 'set'

class Debendable
  def initialize
    @cache = {}
    @libraries = Set.new
    @dependencies = {}
  end

  def run
    ARGV.each do |path|
      if File.directory?(path)
        scan_directory(path)
      else
        scan_file(path)
      end
    end
    output_dependencies
  end

  private

  # Scans a directory recursively for executable files
  def scan_directory(dir)
    Dir.glob(File.join(dir, '**', '*')).each do |file|
      scan_file(file) if File.file?(file) && File.executable?(file)
    end
  end

  # Scans a single file to extract shared library dependencies
  def scan_file(file)
    return unless elf_file?(file)
    shared_libs = get_shared_libs(file)
    shared_libs.each do |lib|
      process_library(lib)
    end
  end

  # Check if a file is an ELF executable
  def elf_file?(file)
    File.open(file, 'rb') do |f|
      f.read(4) == "\x7FELF"
    end
  rescue
    false
  end

  # Extract shared library dependencies using objdump
  def get_shared_libs(file)
    output, status = Open3.capture2e('objdump', '-p', file)
    return [] unless status.success?

    output.scan(/^\s*NEEDED\s+(.+)$/).flatten.map(&:strip)
  end

  # Process a library to determine the package and version required
  def process_library(lib)
    pkg = find_package_for_lib(lib)
    return unless pkg

    if symbols_file_available?(pkg)
      min_version = find_min_version_for_symbols(pkg, lib)
      @dependencies[pkg] = min_version unless min_version.nil?
    else
      @libraries << pkg # Add library if no symbols file
    end
  end

  # Find the package providing the library using dpkg-query
  def find_package_for_lib(lib)
    @cache[lib] ||= begin
      output, status = Open3.capture2e('dpkg-query', '-S', lib)
      status.success? ? output.split(':').first : nil
    end
  end

  # Check if symbols file is available for the package
  def symbols_file_available?(pkg)
    File.exist?("/var/lib/dpkg/info/#{pkg}.symbols")
  end

  # Find the minimum version of the package that provides the necessary symbols
  def find_min_version_for_symbols(pkg, lib)
    symbol_file = "/var/lib/dpkg/info/#{pkg}.symbols"
    return nil unless File.exist?(symbol_file)

    File.readlines(symbol_file).each do |line|
      next unless line.start_with?(lib)
      match = line.match(/\S+\s+\S+\s+(\d+\.\d+)/)
      return match[1] if match
    end

    nil
  end

  # Output the dependencies, including version constraints when applicable
  def output_dependencies
    @libraries.each do |lib|
      puts lib
    end

    @dependencies.each do |pkg, version|
      puts "#{pkg} (>= #{version})"
    end
  end
end

Debendable.new.run
