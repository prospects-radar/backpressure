# frozen_string_literal: true

require "backpressure/checks/design_system/missing_test_id"

RSpec.describe Backpressure::Checks::DesignSystem::MissingTestId do
  it "flags organism without tid that is referenced in Cucumber" do
    Dir.mktmpdir do |dir|
      comp = File.join(dir, "app/components/glass_morph/organisms/dashboard.rb")
      feature = File.join(dir, "features/dashboard.feature")
      FileUtils.mkdir_p(File.dirname(comp))
      FileUtils.mkdir_p(File.dirname(feature))
      File.write(comp, "class Dashboard < Phlex::HTML\n  def view_template\n    div { text 'hi' }\n  end\nend")
      File.write(feature, "Feature: Dashboard\n  Scenario: view dashboard\n")

      index = Backpressure::ProjectIndex.new(classes: [], files: [comp, feature])
      context = Backpressure::Contexts::SourceContext.new(source: File.read(comp), file_path: comp)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations.size).to eq(1)
      expect(check.violations.first.message).to include("dashboard")
    end
  end

  it "passes when organism has tid()" do
    source = "class Dashboard < Phlex::HTML\n  def view_template\n    div(tid('dashboard')) { text 'hi' }\n  end\nend"
    context = Backpressure::Contexts::SourceContext.new(
      source: source,
      file_path: "app/components/glass_morph/organisms/dashboard.rb"
    )
    index = Backpressure::ProjectIndex.new(classes: [], files: [])
    context.define_singleton_method(:project_index) { index }

    check = described_class.new
    check.run(context)
    expect(check.violations).to be_empty
  end

  it "passes when organism is not referenced in Cucumber" do
    Dir.mktmpdir do |dir|
      comp = File.join(dir, "app/components/glass_morph/organisms/sidebar.rb")
      feature = File.join(dir, "features/dashboard.feature")
      FileUtils.mkdir_p(File.dirname(comp))
      FileUtils.mkdir_p(File.dirname(feature))
      File.write(comp, "class Sidebar < Phlex::HTML\n  def view_template\n    nav { text 'nav' }\n  end\nend")
      File.write(feature, "Feature: Dashboard\n  Scenario: view dashboard\n")

      index = Backpressure::ProjectIndex.new(classes: [], files: [comp, feature])
      context = Backpressure::Contexts::SourceContext.new(source: File.read(comp), file_path: comp)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations).to be_empty
    end
  end
end
