# frozen_string_literal: true
require_relative "../lib/debendencies/package_version"

RSpec.describe Debendencies::Private::PackageVersion do
  def compare_versions(v1, v2)
    described_class.new(v1) <=> described_class.new(v2)
  end

  it "handles simple numeric versions" do
    expect(compare_versions("1.2", "1.3")).to eq(-1)
  end

  it "compares versions with epoch" do
    expect(compare_versions("1:1.2", "2:1.1")).to eq(-1)
  end

  it "compares versions with debian_revision" do
    expect(compare_versions("1.2-1", "1.2-2")).to eq(-1)
  end

  it "compares versions with epoch and debian_revision" do
    expect(compare_versions("1:1.2-1", "1:1.2-2")).to eq(-1)
  end

  it "handles tilde in upstream_version" do
    expect(compare_versions("1.2~alpha", "1.2")).to eq(-1)
  end

  it "compares lexically with letters in upstream_version" do
    expect(compare_versions("1.2a", "1.2b")).to eq(-1)
  end

  it "compares versions with mixed alphanumeric characters" do
    expect(compare_versions("1.2-1a", "1.2-1b")).to eq(-1)
  end

  it "compares versions with and without debian_revision" do
    expect(compare_versions("1.2", "1.2-0")).to eq(0)
  end

  it "handles special +really convention" do
    expect(compare_versions("2.3-3+really2.2", "2.3-3")).to eq(1)
  end

  it "handles stable updates with +debNuX" do
    expect(compare_versions("1.4-5+deb10u1", "1.4-5")).to eq(1)
  end

  it "handles backports with ~bpoNuX" do
    expect(compare_versions("1.4-5+deb10u1~bpo9u1", "1.4-5+deb10u1")).to eq(-1)
  end

  it "handles versions with non-standard characters" do
    expect(compare_versions("1.2.3+git20190725", "1.2.3")).to eq(1)
  end

  it "compares versions with omitted epoch and debian_revision" do
    expect(compare_versions("2:1.2.3", "1.2.3-1")).to eq(1)
  end

  it "compares versions with alphanumeric debian_revision" do
    expect(compare_versions("1.2-1abc123", "1.2-1abc124")).to eq(-1)
  end

  it "handles upstream versions with multiple hyphens" do
    expect(compare_versions("1.0-alpha-1", "1.0-1")).to eq(1)
  end
end
