# frozen_string_literal: true

require "tmpdir"
require "yaml"

RSpec.describe Backpressure::Baseline do
  let(:tmpdir) { Dir.mktmpdir("bp_baseline") }
  let(:baseline_path) { File.join(tmpdir, "backpressure_baseline.yml") }

  after { FileUtils.remove_entry(tmpdir) }

  let(:violations) do
    [
      Backpressure::Violation.new(check_name: "CheckA", message: "m1", file: "a.rb", line: 10),
      Backpressure::Violation.new(check_name: "CheckA", message: "m2", file: "b.rb", line: 20),
      Backpressure::Violation.new(check_name: "CheckB", message: "m3", file: "c.rb", line: 5)
    ]
  end

  describe ".write" do
    it "writes a baseline file from violations" do
      described_class.write(violations, path: baseline_path)
      expect(File.exist?(baseline_path)).to be true

      data = YAML.safe_load_file(baseline_path)
      expect(data["checks"]["CheckA"]["count"]).to eq(2)
      expect(data["checks"]["CheckB"]["count"]).to eq(1)
      expect(data["checks"]["CheckA"]["files"]).to contain_exactly("a.rb:10", "b.rb:20")
    end
  end

  describe ".load" do
    it "loads an existing baseline" do
      described_class.write(violations, path: baseline_path)
      baseline = described_class.load(baseline_path)

      expect(baseline.count_for("CheckA")).to eq(2)
      expect(baseline.count_for("CheckB")).to eq(1)
      expect(baseline.count_for("Unknown")).to eq(0)
    end

    it "returns empty baseline when file doesn't exist" do
      baseline = described_class.load(baseline_path)
      expect(baseline.count_for("CheckA")).to eq(0)
      expect(baseline.empty?).to be true
    end
  end

  describe "#new_violations" do
    it "identifies violations not in baseline" do
      described_class.write(violations, path: baseline_path)
      baseline = described_class.load(baseline_path)

      current = violations + [
        Backpressure::Violation.new(check_name: "CheckA", message: "m4", file: "d.rb", line: 30)
      ]

      new_ones = baseline.new_violations(current)
      expect(new_ones.size).to eq(1)
      expect(new_ones.first.file).to eq("d.rb")
    end

    it "returns all violations when no baseline exists" do
      baseline = described_class.load(baseline_path)
      new_ones = baseline.new_violations(violations)
      expect(new_ones.size).to eq(3)
    end
  end

  describe "#tampered?" do
    it "detects when baseline counts increased without update" do
      described_class.write(violations, path: baseline_path)
      baseline = described_class.load(baseline_path)

      expect(baseline.tampered?(violations)).to be false

      data = YAML.safe_load_file(baseline_path)
      data["checks"]["CheckA"]["count"] = 100
      File.write(baseline_path, data.to_yaml)
      tampered_baseline = described_class.load(baseline_path)

      expect(tampered_baseline.tampered?(violations)).to be true
    end
  end
end
