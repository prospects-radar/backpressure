# frozen_string_literal: true

require "backpressure/checks/design_system/orphaned_component"

RSpec.describe Backpressure::Checks::DesignSystem::OrphanedComponent do
  # Helper: build a ClassEntry with a relative-style path that satisfies
  # classes_in("app/components/glass_morph/**/*.rb") via File.fnmatch.
  def make_component_entry(rel_path, name)
    Backpressure::ProjectIndex::ClassEntry.new(
      name: name,
      file: rel_path,
      node: nil,
      superclass_name: nil
    )
  end

  it "flags orphaned component with no external references" do
    comp_rel = "app/components/glass_morph/atoms/button.rb"
    entry = make_component_entry(comp_rel, "Button")

    # Empty files list => references_to searches nothing => no refs found.
    # external_refs will be empty => violation is raised.
    index = Backpressure::ProjectIndex.new(classes: [entry], files: [])
    context = Backpressure::Contexts::SourceContext.new(
      source: "class Button < Phlex::HTML; end",
      file_path: comp_rel
    )
    context.define_singleton_method(:project_index) { index }

    check = described_class.new
    check.run(context)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("Button")
  end

  it "passes when component is referenced externally" do
    Dir.mktmpdir do |dir|
      view_file = File.join(dir, "app/views/test.rb")
      FileUtils.mkdir_p(File.dirname(view_file))
      File.write(view_file, "class TestView; Button.new; end")

      comp_rel = "app/components/glass_morph/atoms/button.rb"
      entry = make_component_entry(comp_rel, "Button")

      # Include the real view file so references_to finds Button there.
      # The ref's r.file will be view_file (absolute), which != comp_rel => external ref.
      index = Backpressure::ProjectIndex.new(classes: [entry], files: [view_file])
      context = Backpressure::Contexts::SourceContext.new(
        source: "class Button < Phlex::HTML; end",
        file_path: comp_rel
      )
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations).to be_empty
    end
  end
end
