# frozen_string_literal: true

require "backpressure/checks/ai/human_oversight/no_fallback_path"

RSpec.describe Backpressure::Checks::AI::HumanOversight::NoFallbackPath do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags agent.run without rescue or fallback" do
    check = run_check("result = agent.run(prompt)")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("fallback path")
  end

  it "passes when rescue is present" do
    source = "result = agent.run(prompt)\nrescue => e\n  fallback_response"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when fallback is present" do
    source = "result = agent.run(prompt) || fallback"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when no .run call is present" do
    check = run_check("def compute; 42; end")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/HumanOversight")
    expect(described_class.check_severity).to eq(:warning)
  end
end
