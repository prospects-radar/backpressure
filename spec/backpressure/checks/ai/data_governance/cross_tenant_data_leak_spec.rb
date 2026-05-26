# frozen_string_literal: true

require "backpressure/checks/ai/data_governance/cross_tenant_data_leak"

RSpec.describe Backpressure::Checks::AI::DataGovernance::CrossTenantDataLeak do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags database query without tenant scoping" do
    check = run_check("users = User.where(active: true)")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("cross-tenant data leak")
  end

  it "passes when acts_as_tenant is present" do
    source = "acts_as_tenant(:account)\nusers = User.where(active: true)"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when Current.account scoping is present" do
    source = "account = Current.account\nusers = User.where(account: account)"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when no database query is present" do
    check = run_check("def process; result = compute(input); end")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/DataGovernance")
    expect(described_class.check_severity).to eq(:error)
  end
end
