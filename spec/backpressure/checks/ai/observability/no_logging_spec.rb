# frozen_string_literal: true

require "backpressure/checks/ai/observability/no_logging"

RSpec.describe Backpressure::Checks::AI::Observability::NoLogging do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags agent with no logging" do
    check = run_check("class MyAgent; def run; provider.complete(prompt: p); end; end")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("logging")
  end

  it "passes when Rails.logger is used" do
    check = run_check("Rails.logger.info('calling AI'); provider.complete(prompt: p)")
    expect(check.violations).to be_empty
  end

  it "passes when RAAF.logger is used" do
    check = run_check("RAAF.logger.debug('result'); provider.complete(prompt: p)")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Observability")
    expect(described_class.check_severity).to eq(:warning)
  end
end
