# frozen_string_literal: true

require "backpressure/checks/design_system/inconsistent_component_usage"

RSpec.describe Backpressure::Checks::DesignSystem::InconsistentComponentUsage do
  it "has correct metadata" do
    expect(described_class.check_category).to eq("DesignSystem")
    expect(described_class.check_severity).to eq(:warning)
    expect(described_class.ai_settings[:provider]).to eq(:test)
  end

  it "runs without error with test provider" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          Button(variant: :primary)
        end
      end
    RUBY
    context = Backpressure::Contexts::PhlexContext.new(source: source, file_path: "app/views/glass_morph/test.rb")
    index = Backpressure::ProjectIndex.new(classes: [], files: [])
    context.define_singleton_method(:project_index) { index }

    check = described_class.new
    check.run(context)
    expect(check.violations).to be_empty
  end
end
