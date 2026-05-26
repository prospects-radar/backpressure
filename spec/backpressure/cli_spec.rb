# frozen_string_literal: true

RSpec.describe Backpressure::CLI do
  describe ".parse" do
    it "parses check command" do
      options = described_class.parse(["check"])
      expect(options[:command]).to eq(:check)
    end

    it "parses --only flag" do
      options = described_class.parse(["check", "--only", "NoDirectAR"])
      expect(options[:only]).to eq(["NoDirectAR"])
    end

    it "parses --format flag" do
      options = described_class.parse(["check", "--format", "json"])
      expect(options[:format]).to eq(:json)
    end

    it "parses --update-baseline flag" do
      options = described_class.parse(["check", "--update-baseline"])
      expect(options[:update_baseline]).to be true
    end

    it "parses --no-cache flag" do
      options = described_class.parse(["check", "--no-cache"])
      expect(options[:cache]).to be false
    end

    it "parses file path arguments" do
      options = described_class.parse(["check", "app/controllers/"])
      expect(options[:paths]).to eq(["app/controllers/"])
    end

    it "parses list command" do
      options = described_class.parse(["list"])
      expect(options[:command]).to eq(:list)
    end

    it "parses fix command" do
      options = described_class.parse(["fix"])
      expect(options[:command]).to eq(:fix)
    end

    it "parses --ai-fix flag on fix command" do
      options = described_class.parse(["fix", "--ai-fix"])
      expect(options[:ai_fix]).to be true
    end

    it "parses --interactive flag on fix command" do
      options = described_class.parse(["fix", "--interactive"])
      expect(options[:interactive]).to be true
    end
  end
end
