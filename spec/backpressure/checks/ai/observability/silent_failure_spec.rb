# frozen_string_literal: true

require "backpressure/checks/ai/observability/silent_failure"

RSpec.describe Backpressure::Checks::AI::Observability::SilentFailure do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags rescue without logging or re-raising" do
    source = <<~RUBY
      begin
        provider.complete(prompt: p)
      rescue StandardError
        nil
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("silent failure")
  end

  it "passes when rescue logs the error" do
    source = <<~'RUBY'
      begin
        provider.complete(prompt: p)
      rescue StandardError => e
        log("error: #{e.message}")
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when rescue re-raises" do
    source = <<~RUBY
      begin
        provider.complete(prompt: p)
      rescue StandardError
        raise
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Observability")
    expect(described_class.check_severity).to eq(:warning)
  end
end
