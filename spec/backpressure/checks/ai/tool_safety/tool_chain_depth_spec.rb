# frozen_string_literal: true

require "backpressure/checks/ai/tool_safety/tool_chain_depth"

RSpec.describe Backpressure::Checks::AI::ToolSafety::ToolChainDepth do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags pipeline exceeding max depth" do
    # 6 >> operators means 7 agents
    source = "pipeline = a1 >> a2 >> a3 >> a4 >> a5 >> a6 >> a7"
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("7 agents")
  end

  it "passes when pipeline is within max depth" do
    source = "pipeline = a1 >> a2 >> a3"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when source has no pipeline" do
    check = run_check("class SimpleAgent; end")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/ToolSafety")
    expect(described_class.check_severity).to eq(:warning)
  end
end
