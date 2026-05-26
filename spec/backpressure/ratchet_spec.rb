# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::Ratchet do
  let(:tmpdir) { Dir.mktmpdir("bp_ratchet") }
  let(:baseline_path) { File.join(tmpdir, "baseline.yml") }

  after { FileUtils.remove_entry(tmpdir) }

  let(:baseline_violations) do
    [
      Backpressure::Violation.new(check_name: "CheckA", message: "m", file: "a.rb", line: 10),
      Backpressure::Violation.new(check_name: "CheckA", message: "m", file: "b.rb", line: 20)
    ]
  end

  describe "#evaluate" do
    it "passes when violations are within baseline" do
      Backpressure::Baseline.write(baseline_violations, path: baseline_path)
      ratchet = described_class.new(baseline_path: baseline_path, anti_tamper: true)

      result = ratchet.evaluate(baseline_violations)
      expect(result.pass?).to be true
      expect(result.new_violations).to be_empty
    end

    it "fails when new violations appear" do
      Backpressure::Baseline.write(baseline_violations, path: baseline_path)
      ratchet = described_class.new(baseline_path: baseline_path, anti_tamper: true)

      current = baseline_violations + [
        Backpressure::Violation.new(check_name: "CheckA", message: "m", file: "c.rb", line: 30)
      ]

      result = ratchet.evaluate(current)
      expect(result.pass?).to be false
      expect(result.new_violations.size).to eq(1)
    end

    it "passes when no baseline exists (first run)" do
      ratchet = described_class.new(baseline_path: baseline_path, anti_tamper: true)
      result = ratchet.evaluate(baseline_violations)
      expect(result.pass?).to be true
    end

    it "fails on tampered baseline" do
      Backpressure::Baseline.write(baseline_violations, path: baseline_path)

      data = YAML.safe_load_file(baseline_path)
      data["checks"]["CheckA"]["count"] = 999
      File.write(baseline_path, data.to_yaml)

      ratchet = described_class.new(baseline_path: baseline_path, anti_tamper: true)
      result = ratchet.evaluate(baseline_violations)
      expect(result.pass?).to be false
      expect(result.tampered?).to be true
    end
  end
end
