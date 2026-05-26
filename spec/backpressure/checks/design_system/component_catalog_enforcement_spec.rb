# frozen_string_literal: true

require "backpressure/checks/design_system/component_catalog_enforcement"

RSpec.describe Backpressure::Checks::DesignSystem::ComponentCatalogEnforcement do
  def make_index(component_files)
    classes = component_files.map do |path|
      Backpressure::ProjectIndex::ClassEntry.new(
        name: File.basename(path, ".rb").split("_").map(&:capitalize).join,
        file: path,
        node: nil,
        superclass_name: nil
      )
    end
    Backpressure::ProjectIndex.new(classes: classes, files: component_files)
  end

  def run_check(source, component_files:, file_path: "app/views/glass_morph/test.rb")
    context = Backpressure::Contexts::PhlexContext.new(source: source, file_path: file_path)
    index = make_index(component_files)
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    check
  end

  it "flags raw button when Button atom exists" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          button(class: "btn")
        end
      end
    RUBY
    check = run_check(source, component_files: ["app/components/glass_morph/atoms/button.rb"])
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("Button")
  end

  it "passes when no matching atom exists" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          canvas(width: 200)
        end
      end
    RUBY
    check = run_check(source, component_files: ["app/components/glass_morph/atoms/button.rb"])
    expect(check.violations).to be_empty
  end

  it "skips files without view_template" do
    source = "class Foo; end"
    context = Backpressure::Contexts::PhlexContext.new(source: source, file_path: "app/views/glass_morph/test.rb")
    index = make_index([])
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    expect(check.skipped?).to be true
  end

  it "passes when catalog is empty" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          button(class: "btn")
        end
      end
    RUBY
    check = run_check(source, component_files: [])
    expect(check.violations).to be_empty
  end
end
