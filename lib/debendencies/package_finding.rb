# frozen_string_literal: true
require "open3"
require_relative "errors"
require_relative "elf_analysis"
require_relative "utils"

class Debendencies
  module Private
    class << self
      # Finds all packages providing a specific library soname. This is done using `dpkg-query -S`.
      #
      # @return [Array<String>] List of package names, like "libc6". Does not include any architecture
      #   identifiers returned by `dpkg-query -S`
      def find_packages_providing_lib(soname)
        output, error_output, status = Open3.capture3("dpkg-query", "-S", "*/#{soname}")
        if !status.success?
          if !status.signaled? && error_output.include?("no path found matching pattern")
            return []
          else
            raise Error, "Error finding packages that provide #{soname}: 'dpkg-query' failed: #{status}: #{error_output.chomp}"
          end
        end

        # Output is in the following format and could contain alternatives:
        # libfoo1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
        # libfoofork1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
        #
        # The architecture could be omitted, like so:
        # libfoo1: /usr/lib/x86_64-linux-gnu/libfoo1.so.1

        output.each_line.map { |line| line.split(":", 2).first }
      end

      # Finds the minimum version of the package that provides the necessary library symbols
      # used by the given ELF files.
      def find_min_package_version(soname, symbols_file_path, dependent_elf_file_paths, symbol_extraction_cache = {})
        dynamic_symbols = extract_dynamic_symbols(dependent_elf_file_paths, symbol_extraction_cache)
        return nil if dynamic_symbols.empty?

        max_used_package_version = nil

        File.open(symbols_file_path, "r:utf-8") do |f|
          skip_symbols_file_io_until_library_section(f, soname)

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

      def find_symbols_file(package_name)
        path = "/var/lib/dpkg/info/#{package_name}.symbols"
        path if File.exist?(path)
      end

      private

      # Skips lines in the symbols file until we encounter the start of the section for the given library
      def skip_symbols_file_io_until_library_section(io, soname)
        io.each_line do |line|
          break if line.start_with?("#{soname} ")
        end
      end
    end
  end
end
