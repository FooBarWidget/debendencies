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

    def as_json
      result = { name: name }
      result[:version_constraints] = version_constraints.map { |vc| vc.as_json } if version_constraints
      result
    end

    def to_s
      if version_constraints.nil?
        name
      else
        "#{name} (#{version_constraints.map { |vc| vc.to_s }.join(", ")})"
      end
    end
  end

  # Represents a version constraint, e.g., `>= 2.28-1`.
  class VersionConstraint
    # A comparison operator, e.g., `>=`.
    #
    # @return [String]
    attr_reader :operator

    # A Debian package version, e.g., `2.28-1`.
    # @return [String]
    attr_reader :version

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

    def as_json
      { operator: operator, version: version }
    end

    def to_s
      "#{operator} #{version}"
    end
  end
end
