# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Integration: loading all checks" do
  checks_dir = File.expand_path("../../lib/backpressure/checks", __dir__)
  yaml_dir = File.expand_path("../../checks/yaml", __dir__)

  Dir.glob(File.join(checks_dir, "**", "*.rb")).sort.each { |f| require f }

  ruby_checks = ObjectSpace.each_object(Class).select { |c|
    c < Backpressure::Check && c != Backpressure::AiCheck && c.name
  }

  yaml_checks = Backpressure::YamlLoader.load_all(yaml_dir)

  describe "Ruby check classes" do
    it "loads all 43 check classes" do
      expect(ruby_checks.size).to eq(43)
    end

    it "covers all expected categories" do
      categories = ruby_checks.map { |c| c.check_category }.compact.uniq.sort

      expect(categories).to include(
        "AI/Cost",
        "AI/DataGovernance",
        "AI/HumanOversight",
        "AI/Observability",
        "AI/OutputSafety",
        "AI/PromptSafety",
        "AI/Testing",
        "AI/ToolSafety",
        "Architecture",
        "DesignSystem",
        "Hygiene",
        "MultiTenancy",
        "Testing"
      )
    end

    it "has no duplicate check names" do
      names = ruby_checks.map { |c| c.check_name }
      expect(names).to eq(names.uniq)
    end

    it "every check has a category" do
      missing = ruby_checks.select { |c| c.check_category.nil? }
      expect(missing).to be_empty, "Checks without category: #{missing.map(&:check_name).join(', ')}"
    end

    it "every check has a severity" do
      ruby_checks.each do |check_class|
        expect(check_class.check_severity).to be_a(Symbol)
      end
    end
  end

  describe "YAML AI checks" do
    it "loads all 12 YAML check definitions" do
      expect(yaml_checks.size).to eq(12)
    end

    it "includes expected check names" do
      names = yaml_checks.map { |c| c.check_name }

      expect(names).to include(
        "PromptClarity",
        "CommentedOutCode",
        "PromptInjectionSurface",
        "HallucinationGuardMissing",
        "ExpensiveModelForSimpleTask",
        "NoEdgeCaseTests"
      )
    end

    it "every YAML check inherits from AiCheck" do
      yaml_checks.each do |check_class|
        expect(check_class).to be < Backpressure::AiCheck
      end
    end

    it "every YAML check has a category" do
      missing = yaml_checks.select { |c| c.check_category.nil? }
      expect(missing).to be_empty, "YAML checks without category: #{missing.map(&:check_name).join(', ')}"
    end

    it "covers RAAF and Convention categories" do
      categories = yaml_checks.map { |c| c.check_category }.compact.uniq.sort
      expect(categories).to include("Convention", "RAAF")
    end
  end

  describe "combined check set" do
    it "totals 55 checks across Ruby and YAML" do
      expect(ruby_checks.size + yaml_checks.size).to eq(55)
    end

    it "covers all 15 categories" do
      all_categories = (
        ruby_checks.map { |c| c.check_category } +
        yaml_checks.map { |c| c.check_category }
      ).compact.uniq.sort

      expect(all_categories.size).to eq(15)
      expect(all_categories).to eq([
        "AI/Cost",
        "AI/DataGovernance",
        "AI/HumanOversight",
        "AI/Observability",
        "AI/OutputSafety",
        "AI/PromptSafety",
        "AI/Testing",
        "AI/ToolSafety",
        "Architecture",
        "Convention",
        "DesignSystem",
        "Hygiene",
        "MultiTenancy",
        "RAAF",
        "Testing"
      ])
    end
  end
end
