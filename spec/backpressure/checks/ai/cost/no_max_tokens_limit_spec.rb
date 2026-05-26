# frozen_string_literal: true

require "backpressure/checks/ai/cost/no_max_tokens_limit"

RSpec.describe Backpressure::Checks::AI::Cost::NoMaxTokensLimit do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags AI call without max_tokens" do
    check = run_check("result = provider.complete(prompt: p)")
    expect(check.violations.size).to eq(1)
  end

  it "passes when max_tokens present" do
    check = run_check("result = provider.complete(prompt: p, max_tokens: 1024)")
    expect(check.violations).to be_empty
  end

  it "passes when no AI call is made" do
    check = run_check("def greet; 'hello'; end")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Cost")
    expect(described_class.check_severity).to eq(:warning)
  end
end
