# frozen_string_literal: true

require "backpressure/checks/ai/cost/large_context_window"

RSpec.describe Backpressure::Checks::AI::Cost::LargeContextWindow do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags File.read into prompt" do
    source = <<~RUBY
      content = File.read("big_document.txt")
      provider.complete(prompt: content)
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("summarization")
  end

  it "passes when no file read is present" do
    check = run_check("provider.complete(prompt: 'static prompt')")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Cost")
    expect(described_class.check_severity).to eq(:warning)
  end
end
