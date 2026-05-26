# frozen_string_literal: true

require "backpressure/checks/ai/cost/unbounded_retry_loop"

RSpec.describe Backpressure::Checks::AI::Cost::UnboundedRetryLoop do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags retry without a cap" do
    source = <<~RUBY
      begin
        provider.complete(prompt: p)
      rescue
        retry
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("runaway cost")
  end

  it "passes when max_attempts is present" do
    source = <<~RUBY
      attempts = 0
      max_attempts = 3
      begin
        provider.complete(prompt: p)
      rescue
        attempts += 1
        retry if attempts < max_attempts
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when no retry present" do
    check = run_check("result = provider.complete(prompt: p)")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Cost")
    expect(described_class.check_severity).to eq(:error)
  end
end
