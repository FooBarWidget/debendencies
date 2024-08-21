require_relative "lib/debendencies/version"

Gem::Specification.new do |spec|
  spec.name = "debendencies"
  spec.version = Debendencies::VERSION_STRING
  spec.authors = ["Hongli Lai"]
  spec.email = ["hongli@hongli.nl"]

  spec.summary = %q{Debian package shared library dependencies detector}
  spec.description = %q{Scans executables and shared libraries for their shared library dependencies, and outputs a list of Debian package names that provide those libraries.}
  spec.homepage = "https://github.com/FooBarWidget/debendencies"
  spec.license = "MIT"

  spec.files = Dir["lib/**/*.rb"]
  spec.bindir = "bin"
  spec.executables = ["debendencies"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "set", "~> 1"
  spec.add_runtime_dependency "stringio", "~> 3"
  spec.add_runtime_dependency "json", "~> 2"
  spec.add_runtime_dependency "optparse", ">= 0.4", "< 2"
  spec.add_runtime_dependency "open3", ">= 0.1", "< 2"
  spec.add_runtime_dependency "tmpdir", ">= 0.1", "< 2"
  spec.add_runtime_dependency "fileutils", "~> 1"
  spec.add_runtime_dependency "tempfile", ">= 0.1", "< 2"
end
