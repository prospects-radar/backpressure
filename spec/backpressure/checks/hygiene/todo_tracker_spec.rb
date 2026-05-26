# frozen_string_literal: true

require "backpressure/checks/hygiene/todo_tracker"

RSpec.describe Backpressure::Checks::Hygiene::TodoTracker do
  def run_check(source, file_path: "app/models/user.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags TODO comments" do
    check = run_check("# TODO: fix this\ncode\n# TODO: and this\n")
    expect(check.violations.size).to eq(2)
    expect(check.violations.map(&:line)).to eq([1, 3])
  end

  it "flags FIXME comments" do
    check = run_check("# FIXME: broken\n")
    expect(check.violations.size).to eq(1)
  end

  it "flags HACK comments" do
    check = run_check("# HACK: workaround\n")
    expect(check.violations.size).to eq(1)
  end

  it "ignores normal comments" do
    check = run_check("# This is a normal comment\ncode\n")
    expect(check.violations).to be_empty
  end

  it "is case-insensitive" do
    check = run_check("# todo: lowercase\n")
    expect(check.violations.size).to eq(1)
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("Hygiene")
    expect(described_class.check_severity).to eq(:warning)
    expect(described_class.ratchet_mode).to eq(:strict)
  end
end
