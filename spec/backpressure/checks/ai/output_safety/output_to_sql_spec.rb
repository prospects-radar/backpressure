# frozen_string_literal: true

require "backpressure/checks/ai/output_safety/output_to_sql"

RSpec.describe Backpressure::Checks::AI::OutputSafety::OutputToSQL do
  def run_check(source, file_path: "app/services/test.rb")
    context = Backpressure::Contexts::AstContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags string interpolation in where clause" do
    source = 'User.where("name = #{ai_result}")'
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("SQL injection")
  end

  it "passes with symbol-based where" do
    source = "User.where(name: ai_result)"
    check = run_check(source)
    expect(check.violations).to be_empty
  end
end
