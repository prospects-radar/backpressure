# frozen_string_literal: true

require "backpressure/checks/ai/testing/determinism_untested"

RSpec.describe Backpressure::Checks::AI::Testing::DeterminismUntested do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags agent using temperature: 0" do
    check = run_check("provider.complete(prompt: p, temperature: 0)")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("temperature: 0")
  end

  it "passes when temperature is not 0" do
    check = run_check("provider.complete(prompt: p, temperature: 0.7)")
    expect(check.violations).to be_empty
  end

  it "passes when temperature is not set at all" do
    check = run_check("provider.complete(prompt: p, max_tokens: 512)")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Testing")
    expect(described_class.check_severity).to eq(:info)
  end
end
