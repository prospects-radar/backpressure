# frozen_string_literal: true

require "backpressure/checks/design_system/component_coverage_drift"

RSpec.describe Backpressure::Checks::DesignSystem::ComponentCoverageDrift do
  def run_check(source, file_path: "app/views/glass_morph/test.rb")
    context = Backpressure::Contexts::PhlexContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "reports coverage metric" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          div do
            Button(variant: :primary)
          end
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("coverage")
  end

  it "skips files without view_template" do
    check = run_check("class Foo; end")
    expect(check.skipped?).to be true
  end

  it "skips when tree has no nodes" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
    expect(check.skipped?).to be false
  end

  it "has ratchet :strict" do
    expect(described_class.ratchet_mode).to eq(:strict)
  end
end
