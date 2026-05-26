# frozen_string_literal: true

require "backpressure/checks/ai/observability/no_trace_id"

RSpec.describe Backpressure::Checks::AI::Observability::NoTraceId do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags agent call without trace_id" do
    check = run_check("other_agent.run(input: data)")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("trace")
  end

  it "passes when trace_id is passed" do
    check = run_check("other_agent.run(input: data, trace_id: tid)")
    expect(check.violations).to be_empty
  end

  it "passes when correlation_id is passed" do
    check = run_check("other_agent.run(input: data, correlation_id: cid)")
    expect(check.violations).to be_empty
  end

  it "passes when no .run call is made" do
    check = run_check("def greet; 'hello'; end")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Observability")
    expect(described_class.check_severity).to eq(:info)
  end
end
