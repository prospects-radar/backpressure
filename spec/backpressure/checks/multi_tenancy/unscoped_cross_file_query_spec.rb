# frozen_string_literal: true

require "backpressure/checks/multi_tenancy/unscoped_cross_file_query"

RSpec.describe Backpressure::Checks::MultiTenancy::UnscopedCrossFileQuery do
  def run_check(source, file_path: "app/services/user_service.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags where query without tenant scoping" do
    check = run_check("users = User.where(active: true)")
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("tenant scoping")
  end

  it "flags find_by without tenant scoping" do
    check = run_check("user = User.find_by(email: params[:email])")
    expect(check.violations.size).to eq(1)
  end

  it "passes when acts_as_tenant is present" do
    source = "acts_as_tenant(:account)\nusers = User.where(active: true)"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when Current.account is present" do
    source = "account = Current.account\nusers = User.where(account: account)"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when ActsAsTenant is referenced" do
    source = "ActsAsTenant.with_tenant(account) { User.all }"
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "passes when no query method is present" do
    check = run_check("def process(data); data.upcase; end")
    expect(check.violations).to be_empty
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("MultiTenancy")
    expect(described_class.check_severity).to eq(:error)
  end
end
