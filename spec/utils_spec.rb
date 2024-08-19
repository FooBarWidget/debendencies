require_relative "../lib/debendencies/utils"

RSpec.describe Debendencies::Private do
  describe ".path_resembles_library?" do
    it "returns true for a path ending with .so" do
      path = "libfoo.so"
      expect(described_class.path_resembles_library?(path)).to be true
    end

    it "returns true for a path ending with .so.1" do
      path = "libfoo.so.1"
      expect(described_class.path_resembles_library?(path)).to be true
    end

    it "returns false for a path not resembling a library" do
      path = "libfoo.txt"
      expect(described_class.path_resembles_library?(path)).to be false
    end
  end
end
