# frozen_string_literal: true

require "backpressure/checks/ai/cost/missing_cacheability"

RSpec.describe Backpressure::Checks::AI::Cost::MissingCacheability do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags deterministic prompt without caching" do
    check = run_check("provider.complete(prompt: p, temperature: 0)")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("caching")
  end

  it "passes when caching is present" do
    check = run_check("Rails.cache.fetch(key) { provider.complete(prompt: p, temperature: 0) }")
    expect(check.violations).to be_empty
  end

  it "passes when temperature is not 0" do
    check = run_check("provider.complete(prompt: p, temperature: 0.7)")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Cost")
    expect(described_class.check_severity).to eq(:info)
  end
end
