# frozen_string_literal: true

require "backpressure/checks/ai/testing/prompt_without_test"

RSpec.describe Backpressure::Checks::AI::Testing::PromptWithoutTest do
  def run_check(source, file_path:, index:)
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    check
  end

  it "flags prompt with no corresponding spec in project index" do
    index = Backpressure::ProjectIndex.new(classes: [], files: [])
    check = run_check(
      "class SummaryPrompt; end",
      file_path: "app/ai/prompts/summary_prompt.rb",
      index: index
    )
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("spec/ai/prompts/summary_prompt_spec.rb")
  end

  it "passes when spec file is in project index" do
    index = Backpressure::ProjectIndex.new(classes: [], files: ["spec/ai/prompts/summary_prompt_spec.rb"])
    check = run_check(
      "class SummaryPrompt; end",
      file_path: "app/ai/prompts/summary_prompt.rb",
      index: index
    )
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Testing")
    expect(described_class.check_severity).to eq(:warning)
  end
end
