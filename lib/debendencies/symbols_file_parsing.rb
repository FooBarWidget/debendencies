# frozen_string_literal: true

class Debendencies
  module Private
    class << self
      # Parses a symbols file. Yields:
      #
      # - All symbols for the specified library soname.
      # - The package version that provides that symbol.
      #
      # For example, it yields `["fopen@GLIBC_1.0", "5"]`.
      #
      # @param path [String] Path to the symbols file.
      # @param soname [String] Soname of the library to yield symbols for.
      # @yield [Array<String>]
      def list_symbols(path, soname)
        File.open(path, "r:utf-8") do |f|
          # Skips lines in the symbols file until we encounter the start of the section for the given library
          f.each_line do |line|
            break if line.start_with?("#{soname} ")
          end

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
            yield [symbol.sub(/@Base$/, ""), package_version]
          end
        end
      end

      def find_symbols_file(package_name, architecture)
        path = File.join(symbols_dir, "#{package_name}:#{architecture}.symbols")
        path if File.exist?(path)
      end

      private

      # Mocked during tests.
      def symbols_dir
        "/var/lib/dpkg/info"
      end
    end
  end
end
