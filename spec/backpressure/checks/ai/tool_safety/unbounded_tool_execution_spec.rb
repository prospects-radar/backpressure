# frozen_string_literal: true

require "backpressure/checks/ai/tool_safety/unbounded_tool_execution"

RSpec.describe Backpressure::Checks::AI::ToolSafety::UnboundedToolExecution do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags tool execution without timeout" do
    check = run_check("def execute; build_tool(:search) { query(input) }; end")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("timeout")
  end

  it "passes when timeout is present" do
    source = "def execute; Timeout.timeout(30) { build_tool(:search) { query(input) } }; end"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when source has no tool registration" do
    check = run_check("class AgentHelper; def helper_method; end; end")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/ToolSafety")
    expect(described_class.check_severity).to eq(:warning)
  end
end
