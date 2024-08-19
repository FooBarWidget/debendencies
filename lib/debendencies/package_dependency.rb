# frozen_string_literal: true

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

    def as_json
      { operator: operator, version: version }
    end

    def to_s
      "#{operator} #{version}"
    end
  end
end
