# frozen_string_literal: true

require "backpressure/checks/ai/tool_safety/overprivileged_tool_set"

RSpec.describe Backpressure::Checks::AI::ToolSafety::OverprivilegedToolSet do
  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/ToolSafety")
    expect(described_class.check_severity).to eq(:warning)
    expect(described_class.ai_settings[:provider]).to eq(:test)
  end

  it "runs without error on simple source" do
    context = Backpressure::Contexts::SourceContext.new(
      source: "class ReadOnlyAgent; end",
      file_path: "app/ai/agents/test.rb"
    )
    check = described_class.new
    check.run(context)
    expect(check.violations).to be_empty
  end
end
