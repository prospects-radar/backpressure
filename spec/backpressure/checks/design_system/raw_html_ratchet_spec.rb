# frozen_string_literal: true

require "backpressure/checks/design_system/raw_html_ratchet"

RSpec.describe Backpressure::Checks::DesignSystem::RawHTMLRatchet do
  def run_check(source, file_path: "app/views/glass_morph/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags raw HTML element calls" do
    source = <<~RUBY
      def view_template
        div(class: "wrapper") do
          span { text "hello" }
          Button(variant: :primary)
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(2)
    expect(check.violations.map(&:line)).to eq([2, 3])
  end

  it "does not flag component calls (uppercase)" do
    source = <<~RUBY
      def view_template
        Button(variant: :primary)
        GlassCard(variant: :solid)
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "scopes to glass_morph files" do
    expect(described_class.matches_file?("app/views/glass_morph/test.rb")).to be true
    expect(described_class.matches_file?("app/models/user.rb")).to be false
  end

  it "has ratchet :strict" do
    expect(described_class.ratchet_mode).to eq(:strict)
  end
end
