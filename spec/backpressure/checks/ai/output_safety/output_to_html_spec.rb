# frozen_string_literal: true

require "backpressure/checks/ai/output_safety/output_to_html"

RSpec.describe Backpressure::Checks::AI::OutputSafety::OutputToHTML do
  def run_check(source, file_path: "app/views/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags raw() calls" do
    check = run_check("raw(ai_output)")
    expect(check.violations.size).to eq(1)
  end

  it "flags html_safe" do
    check = run_check("ai_output.html_safe")
    expect(check.violations.size).to eq(1)
  end

  it "passes safe output" do
    check = run_check("text ai_output")
    expect(check.violations).to be_empty
  end
end
