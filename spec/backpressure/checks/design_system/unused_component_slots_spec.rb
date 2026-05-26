# frozen_string_literal: true

require "backpressure/checks/design_system/unused_component_slots"

RSpec.describe Backpressure::Checks::DesignSystem::UnusedComponentSlots do
  it "flags component with yield but no block callers" do
    Dir.mktmpdir do |dir|
      comp = File.join(dir, "app/components/glass_morph/atoms/card.rb")
      view = File.join(dir, "app/views/test.rb")
      FileUtils.mkdir_p(File.dirname(comp))
      FileUtils.mkdir_p(File.dirname(view))
      File.write(comp, "class Card < Phlex::HTML\n  def view_template\n    yield\n  end\nend")
      File.write(view, "Card(variant: :solid)")

      index = Backpressure::ProjectIndex.new(classes: [], files: [comp, view])
      context = Backpressure::Contexts::SourceContext.new(source: File.read(comp), file_path: comp)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations.size).to eq(1)
      expect(check.violations.first.message).to include("Card")
    end
  end

  it "passes when a caller passes a block" do
    Dir.mktmpdir do |dir|
      comp = File.join(dir, "app/components/glass_morph/atoms/card.rb")
      view = File.join(dir, "app/views/test.rb")
      FileUtils.mkdir_p(File.dirname(comp))
      FileUtils.mkdir_p(File.dirname(view))
      File.write(comp, "class Card < Phlex::HTML\n  def view_template\n    yield\n  end\nend")
      File.write(view, "Card(variant: :solid) do\n  text 'hi'\nend")

      index = Backpressure::ProjectIndex.new(classes: [], files: [comp, view])
      context = Backpressure::Contexts::SourceContext.new(source: File.read(comp), file_path: comp)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations).to be_empty
    end
  end

  it "passes when component source has no yield" do
    Dir.mktmpdir do |dir|
      comp = File.join(dir, "app/components/glass_morph/atoms/button.rb")
      FileUtils.mkdir_p(File.dirname(comp))
      File.write(comp, "class Button < Phlex::HTML\n  def view_template\n    span { text 'btn' }\n  end\nend")

      index = Backpressure::ProjectIndex.new(classes: [], files: [comp])
      context = Backpressure::Contexts::SourceContext.new(source: File.read(comp), file_path: comp)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations).to be_empty
    end
  end
end
