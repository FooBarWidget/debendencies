require "stringio"
require_relative "../lib/debendencies/elf_analysis"

RSpec.describe Debendencies::Private do
  describe ".extract_soname_and_dependency_libs" do
    let(:path) { "dummy_path" }

    it "returns the dependencies and soname" do
      objdump_output = <<~OUTPUT
        NEEDED libfoo.so
        NEEDED libbar.so
        SONAME libbaz.so
      OUTPUT
      allow(described_class).to \
        receive(:popen).
          with(["objdump", "-p", path], anything).
          and_yield(StringIO.new(objdump_output))

      result = described_class.extract_soname_and_dependency_libs(path)
      expect(result).to eq(["libbaz.so", ["libfoo.so", "libbar.so"]])
    end

    it "returns dependencies and nil when SONAME is not present" do
      objdump_output = <<~OUTPUT
        NEEDED libfoo.so
        NEEDED libbar.so
      OUTPUT
      allow(described_class).to \
        receive(:popen).
          with(["objdump", "-p", path], anything).
          and_yield(StringIO.new(objdump_output))

      result = described_class.extract_soname_and_dependency_libs(path)
      expect(result).to eq([nil, ["libfoo.so", "libbar.so"]])
    end

    it "returns empty dependencies when there are no NEEDED entries" do
      objdump_output = <<~OUTPUT
        SONAME libbaz.so
      OUTPUT
      allow(described_class).to \
        receive(:popen).
          with(["objdump", "-p", path], anything).
          and_yield(StringIO.new(objdump_output))

      result = described_class.extract_soname_and_dependency_libs(path)
      expect(result).to eq(["libbaz.so", []])
    end
  end

  describe ".extract_dynamic_symbols" do
    let(:path1) { "dummy_path1" }
    let(:path2) { "dummy_path2" }

    it "returns the correct set of dynamic symbols" do
      nm_output1 = <<~OUTPUT
                         U wcsncmp
        00000000000b6c90 T wcsnwidth
      OUTPUT
      allow(described_class).to \
        receive(:popen).
          with(["nm", "-D", path1], anything).
          and_yield(StringIO.new(nm_output1))

      nm_output2 = <<~OUTPUT
                         U wcsncmp
                         U foo
        0000000000000001 T bar
      OUTPUT
      allow(described_class).to \
        receive(:popen).
          with(["nm", "-D", path2], anything).
          and_yield(StringIO.new(nm_output2))

      result = described_class.extract_dynamic_symbols([path1, path2])
      expect(result).to eq(Set.new(["wcsncmp", "wcsnwidth", "foo", "bar"]))
    end
  end
end
