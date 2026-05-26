# frozen_string_literal: true

require "backpressure/checks/ai/human_oversight/autonomous_state_change"

RSpec.describe Backpressure::Checks::AI::HumanOversight::AutonomousStateChange do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags update! without approval gate" do
    check = run_check("record.update!(status: 'approved')")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("human approval")
  end

  it "flags transition_to without approval gate" do
    check = run_check("order.transition_to(:shipped)")
    expect(check.violations.size).to eq(1)
  end

  it "passes when requires_approval is present" do
    source = "requires_approval(:manager)\nrecord.update!(status: 'approved')"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when human_review is present" do
    source = "human_review(record)\nrecord.save!"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when no state change is present" do
    check = run_check("result = agent.run(prompt)")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/HumanOversight")
    expect(described_class.check_severity).to eq(:error)
  end
end
