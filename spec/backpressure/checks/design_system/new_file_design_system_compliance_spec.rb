# frozen_string_literal: true

require "backpressure/checks/design_system/raw_html_ratchet"
require "backpressure/checks/design_system/new_file_design_system_compliance"

RSpec.describe Backpressure::Checks::DesignSystem::NewFileDesignSystemCompliance do
  def run_check(source, file_path: "app/views/glass_morph/new_view.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags any raw HTML in new files" do
    source = <<~RUBY
      def view_template
        div(class: "wrapper")
        Button(variant: :primary)
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("New GlassMorph file")
  end

  it "passes clean files" do
    source = <<~RUBY
      def view_template
        Button(variant: :primary)
        GlassCard(variant: :solid)
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end
end
