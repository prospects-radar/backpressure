# frozen_string_literal: true

require "backpressure/checks/ai/tool_safety/tool_without_confirmation"

RSpec.describe Backpressure::Checks::AI::ToolSafety::ToolWithoutConfirmation do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags destructive operation without confirmation" do
    check = run_check("def execute; record.delete; end")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("human-in-the-loop")
  end

  it "passes when confirmation gate exists" do
    check = run_check("def execute; requires_approval; record.delete; end")
    expect(check.violations).to be_empty
  end

  it "passes when no destructive operation present" do
    check = run_check("def execute; record.name; end")
    expect(check.violations).to be_empty
  end

  it "flags send_email without confirmation" do
    check = run_check("def execute; send_email(user); end")
    expect(check.violations.size).to eq(1)
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/ToolSafety")
    expect(described_class.check_severity).to eq(:error)
  end
end
