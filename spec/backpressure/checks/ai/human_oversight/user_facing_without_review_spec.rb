# frozen_string_literal: true

require "backpressure/checks/ai/human_oversight/user_facing_without_review"

RSpec.describe Backpressure::Checks::AI::HumanOversight::UserFacingWithoutReview do
  def run_check(source, file_path: "app/controllers/test_controller.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags agent result rendered without moderation" do
    check = run_check("render json: agent_result")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("moderation/review")
  end

  it "passes when moderation is present" do
    source = "output = moderate(agent_result)\nrender json: output"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when review is present" do
    source = "reviewed = review(agent_result)\nrender json: reviewed"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when no agent result pattern is present" do
    check = run_check("def index; render json: { ok: true }; end")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/HumanOversight")
    expect(described_class.check_severity).to eq(:warning)
  end
end
