# frozen_string_literal: true

RSpec.describe Backpressure::Violation do
  subject(:violation) do
    described_class.new(
      check_name: "NoDirectAR",
      category: "Architecture",
      severity: :warning,
      message: "Use a service object",
      file: "app/controllers/foo.rb",
      line: 42,
      column: 5,
      auto_correctable: false
    )
  end

  it "stores all attributes" do
    expect(violation.check_name).to eq("NoDirectAR")
    expect(violation.category).to eq("Architecture")
    expect(violation.severity).to eq(:warning)
    expect(violation.message).to eq("Use a service object")
    expect(violation.file).to eq("app/controllers/foo.rb")
    expect(violation.line).to eq(42)
    expect(violation.column).to eq(5)
    expect(violation.auto_correctable).to be false
  end

  it "has a location string" do
    expect(violation.location).to eq("app/controllers/foo.rb:42:5")
  end

  it "defaults column to 0" do
    v = described_class.new(check_name: "Test", message: "msg", file: "foo.rb", line: 1)
    expect(v.column).to eq(0)
  end

  it "defaults severity to :warning" do
    v = described_class.new(check_name: "Test", message: "msg", file: "foo.rb", line: 1)
    expect(v.severity).to eq(:warning)
  end

  it "is sortable by file then line" do
    v1 = described_class.new(check_name: "A", message: "m", file: "b.rb", line: 10)
    v2 = described_class.new(check_name: "A", message: "m", file: "a.rb", line: 5)
    v3 = described_class.new(check_name: "A", message: "m", file: "a.rb", line: 1)
    expect([v1, v2, v3].sort).to eq([v3, v2, v1])
  end

  describe "#identity" do
    it "returns a stable hash for ratcheting comparison" do
      expect(violation.identity).to eq("NoDirectAR:app/controllers/foo.rb:42")
    end
  end
end
