# frozen_string_literal: true

require "yaml"
require "tempfile"

RSpec.describe Backpressure::Configuration do
  subject(:config) { described_class.new }

  it "has default check_paths" do
    expect(config.check_paths).to eq(["checks/"])
  end

  it "has default include patterns" do
    expect(config.include_patterns).to eq(["**/*.rb"])
  end

  it "has default exclude patterns" do
    expect(config.exclude_patterns).to eq([])
  end

  it "has empty ai config by default" do
    expect(config.ai_config).to eq({})
  end

  it "has default cache settings" do
    expect(config.cache_enabled).to be true
    expect(config.cache_dir).to eq(".backpressure_cache")
  end

  it "has default ratchet settings" do
    expect(config.baseline_file).to eq("backpressure_baseline.yml")
    expect(config.anti_tamper).to be true
  end

  it "has default format" do
    expect(config.format).to eq(:pretty)
  end

  describe ".from_file" do
    it "loads settings from YAML" do
      yaml = {
        "check_paths" => ["custom_checks/", "ai_checks/"],
        "include" => ["app/**/*.rb"],
        "exclude" => ["vendor/**"],
        "format" => "json",
        "ai" => {
          "default_provider" => "gemini",
          "tiers" => { "cheap" => "gemini-2.0-flash" }
        },
        "cache" => { "enabled" => false, "dir" => "tmp/cache" },
        "ratchet" => { "baseline_file" => "custom_baseline.yml", "anti_tamper" => false },
        "checks" => {
          "NoDirectAR" => { "enabled" => false, "severity" => "error" }
        }
      }

      tmpfile = Tempfile.new(["backpressure", ".yml"])
      tmpfile.write(yaml.to_yaml)
      tmpfile.close

      config = described_class.from_file(tmpfile.path)

      expect(config.check_paths).to eq(["custom_checks/", "ai_checks/"])
      expect(config.include_patterns).to eq(["app/**/*.rb"])
      expect(config.exclude_patterns).to eq(["vendor/**"])
      expect(config.format).to eq(:json)
      expect(config.ai_config["default_provider"]).to eq("gemini")
      expect(config.cache_enabled).to be false
      expect(config.cache_dir).to eq("tmp/cache")
      expect(config.baseline_file).to eq("custom_baseline.yml")
      expect(config.anti_tamper).to be false
      expect(config.check_overrides("NoDirectAR")).to eq({ "enabled" => false, "severity" => "error" })
    ensure
      tmpfile.unlink
    end
  end

  describe "#check_enabled?" do
    it "returns true by default" do
      expect(config.check_enabled?("AnyCheck")).to be true
    end

    it "returns false when disabled in overrides" do
      config = described_class.from_hash("checks" => { "NoDirectAR" => { "enabled" => false } })
      expect(config.check_enabled?("NoDirectAR")).to be false
    end
  end
end
