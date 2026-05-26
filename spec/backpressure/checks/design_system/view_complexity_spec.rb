# frozen_string_literal: true

require "backpressure/checks/design_system/view_complexity"

RSpec.describe Backpressure::Checks::DesignSystem::ViewComplexity do
  def run_check(source, file_path: "app/views/glass_morph/test.rb")
    context = Backpressure::Contexts::PhlexContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags views with too many component calls" do
    components = (1..20).map { "        Button(variant: :primary)" }.join("\n")
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          div do
#{components}
          end
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    # 20 Button nodes + 1 div wrapper = 21 total nodes
    expect(check.violations.first.message).to include("21")
  end

  it "passes views under the threshold" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          div do
            Button(variant: :primary)
            GlassCard(variant: :solid)
          end
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "skips files without view_template" do
    check = run_check("class Foo; end")
    expect(check.skipped?).to be true
  end
end
