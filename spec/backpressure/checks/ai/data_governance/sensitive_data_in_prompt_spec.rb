# frozen_string_literal: true

require "backpressure/checks/ai/data_governance/sensitive_data_in_prompt"

RSpec.describe Backpressure::Checks::AI::DataGovernance::SensitiveDataInPrompt do
  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/DataGovernance")
    expect(described_class.check_severity).to eq(:error)
    expect(described_class.ai_settings[:provider]).to eq(:test)
  end

  it "runs without error on simple source" do
    context = Backpressure::Contexts::SourceContext.new(
      source: "class DataAgent; end",
      file_path: "app/ai/agents/test.rb"
    )
    check = described_class.new
    check.run(context)
    expect(check.violations).to be_empty
  end
end
