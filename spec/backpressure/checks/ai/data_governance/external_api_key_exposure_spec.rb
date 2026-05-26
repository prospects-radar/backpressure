# frozen_string_literal: true

require "backpressure/checks/ai/data_governance/external_api_key_exposure"

RSpec.describe Backpressure::Checks::AI::DataGovernance::ExternalAPIKeyExposure do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags hardcoded api_key" do
    check = run_check('client = Client.new(api_key: "sk-abc123")')
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("API key reference")
  end

  it "passes when api_key is loaded from ENV" do
    check = run_check("client = Client.new(api_key: ENV[\"OPENAI_API_KEY\"])")
    expect(check.violations).to be_empty
  end

  it "passes when using Rails credentials" do
    check = run_check("key = Rails.application.credentials.openai_api_key")
    expect(check.violations).to be_empty
  end

  it "passes when api_key reference is in a comment" do
    check = run_check("# api_key must be set via environment variable")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/DataGovernance")
    expect(described_class.check_severity).to eq(:error)
  end
end
