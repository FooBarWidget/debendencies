# frozen_string_literal: true
# Copyright 2024 Hongli Lai
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

class Debendencies
  module Private
    # Represents a package version in the format used by Debian packages.
    # This class is only used internally to compare package versions.
    # It's not exposed through the public API.
    #
    # Version number formats and comparison rules are defined in the Debian Policy Manual:
    # https://www.debian.org/doc/debian-policy/ch-controlfields.html#version
    # https://pmhahn.github.io/dpkg-compare-versions/
    class PackageVersion
      include Comparable

      attr_reader :epoch, :upstream_version, :debian_revision

      def initialize(version_string)
        @version_string = version_string
        # Parse version into epoch, upstream_version, and debian_revision
        @epoch, version = parse_epoch(version_string)
        @upstream_version, @debian_revision = parse_upstream_and_revision(version)
      end

      def <=>(other)
        # Compare epoch
        result = @epoch <=> other.epoch
        return result unless result == 0

        # Compare upstream version
        result = compare_upstream_version(@upstream_version, other.upstream_version)
        return result unless result == 0

        # Compare debian revision
        compare_debian_revision(@debian_revision, other.debian_revision)
      end

      def to_s
        @version_string
      end

      private

      def parse_epoch(version)
        if version.include?(":")
          epoch, rest = version.split(":", 2)
          [epoch.to_i, rest]
        else
          [0, version]
        end
      end

      def parse_upstream_and_revision(version)
        if version.include?("-")
          upstream, debian_revision = version.rpartition("-").values_at(0, 2)
        else
          upstream = version
          debian_revision = ""
        end
        [upstream, debian_revision]
      end

      def compare_upstream_version(ver1, ver2)
        compare_version_parts(split_version(ver1), split_version(ver2))
      end

      def compare_debian_revision(ver1, ver2)
        # Empty string counts as 0 in Debian revision comparison
        ver1 = "0" if ver1.empty?
        ver2 = "0" if ver2.empty?
        compare_version_parts(split_version(ver1), split_version(ver2))
      end

      def split_version(version)
        version.scan(/\d+|[a-zA-Z]+|~|[^\da-zA-Z~]+/)
      end

      def compare_version_parts(parts1, parts2)
        parts1.zip(parts2).each do |part1, part2|
          # Handle nil cases
          part1 ||= ""
          part2 ||= ""

          if part1 =~ /^\d+$/ && part2 =~ /^\d+$/
            result = part1.to_i <=> part2.to_i
          else
            result = compare_lexically(part1, part2)
          end
          return result unless result == 0
        end

        parts1.size <=> parts2.size
      end

      def compare_lexically(part1, part2)
        # Special handling for '~' which sorts before everything else
        return -1 if part1 == "~" && part2 != "~"
        return 1 if part1 != "~" && part2 == "~"

        part1 <=> part2
      end
    end
  end
end
