# frozen_string_literal: true

require "backpressure/checks/ai/observability/audit_trail_missing"

RSpec.describe Backpressure::Checks::AI::Observability::AuditTrailMissing do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags DB mutation without audit trail" do
    source = <<~RUBY
      record = Record.find(id)
      record.update!(status: :processed)
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("audit trail")
  end

  it "passes when audit logging is present" do
    source = <<~RUBY
      log_action("updating record")
      record.update!(status: :processed)
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when paper_trail is used" do
    source = <<~RUBY
      with_paper_trail do
        record.save!
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when no mutation is present" do
    check = run_check("result = provider.complete(prompt: p)")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Observability")
    expect(described_class.check_severity).to eq(:warning)
  end
end
