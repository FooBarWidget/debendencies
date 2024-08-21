# frozen_string_literal: true
require "open3"
require_relative "errors"
require_relative "elf_analysis"
require_relative "symbols_file_parsing"
require_relative "utils"

class Debendencies
  module Private
    class << self
      # Finds the package providing a specific library soname. This is done using `dpkg-query -S`.
      #
      # @return [String] The package name (like "libc6"), or nil if no package provides the library.
      def find_package_providing_lib(soname, architecture)
        output, error_output, status = Open3.capture3("dpkg-query", "-S", "*/#{soname}")
        if !status.success?
          if !status.signaled? && error_output.include?("no path found matching pattern")
            return nil
          else
            raise Error, "Error finding packages that provide #{soname}: 'dpkg-query' failed: #{status}: #{error_output.chomp}"
          end
        end

        # Output is in the following format:
        # libfoo1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
        #
        # The architecture could be omitted, like so:
        # libfoo1: /usr/lib/x86_64-linux-gnu/libfoo1.so.1
        #
        # In theory, the output could contain multiple results, indicating alternatives.
        # We don't support alternatives, so we just return the first result.
        # See rationale in HOW-IT-WORKS.md.

        return nil if output.empty?

        # Split into [[package_name, architecture], ...].
        # The architecture may be nil.
        entries = output.split("\n").map do |line|
          if line =~ /^(\S+?):(?:(\S+?):)? /
            [$1, $2]
          else
            nil
          end
        end.compact

        if (result = entries.find { |e| e[1] == architecture })
          result[0]
        else
          entries[0][0]
        end
      end

      # Finds the minimum version of the package that provides the necessary library symbols
      # used by the given ELF files.
      def find_min_package_version(soname, symbols_file_path, dependent_elf_file_paths, symbol_extraction_cache = {}, logger = nil)
        dependent_symbols = extract_dynamic_symbols(dependent_elf_file_paths, symbol_extraction_cache)
        return nil if dependent_symbols.empty?

        max_used_package_version = nil

        list_symbols(symbols_file_path, soname) do |dependency_symbol, package_version|
          if dependent_symbols.include?(dependency_symbol)
            logger&.info("Found in-use dependency symbol: #{dependency_symbol} (version: #{package_version})")
            if max_used_package_version.nil? || package_version > max_used_package_version
              max_used_package_version = package_version
            end
          end
        end

        max_used_package_version
      end
    end
  end
end
