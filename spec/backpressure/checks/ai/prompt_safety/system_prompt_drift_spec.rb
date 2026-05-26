# frozen_string_literal: true

require "backpressure/checks/ai/prompt_safety/system_prompt_drift"

RSpec.describe Backpressure::Checks::AI::PromptSafety::SystemPromptDrift do
  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/PromptSafety")
    expect(described_class.ai_settings[:provider]).to eq(:test)
  end

  it "runs without error" do
    context = Backpressure::Contexts::SourceContext.new(source: "class Foo; end", file_path: "app/ai/test.rb")
    index = Backpressure::ProjectIndex.new(classes: [], files: [])
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    expect(check.violations).to be_empty
  end
end
