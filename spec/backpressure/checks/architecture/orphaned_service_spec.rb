# frozen_string_literal: true

require "backpressure/checks/architecture/orphaned_service"

RSpec.describe Backpressure::Checks::Architecture::OrphanedService do
  def make_service_entry(name, file_path)
    Backpressure::ProjectIndex::ClassEntry.new(
      name: name,
      file: file_path,
      node: nil,
      superclass_name: nil
    )
  end

  it "flags service with no external references" do
    svc_path = "app/services/lonely_service.rb"
    entry = make_service_entry("LonelyService", svc_path)

    # Empty files list => references_to finds nothing => external_refs empty => violation
    index = Backpressure::ProjectIndex.new(classes: [entry], files: [])
    context = Backpressure::Contexts::SourceContext.new(
      source: "class LonelyService; def run; end; end",
      file_path: svc_path
    )
    context.define_singleton_method(:project_index) { index }

    check = described_class.new
    check.run(context)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("LonelyService")
  end

  it "passes when service is referenced externally" do
    Dir.mktmpdir do |dir|
      ctrl = File.join(dir, "app/controllers/test.rb")
      FileUtils.mkdir_p(File.dirname(ctrl))
      File.write(ctrl, "class TestController; UsedService.run; end")

      svc_path = "app/services/used_service.rb"
      entry = make_service_entry("UsedService", svc_path)

      # Include the real controller file so references_to finds UsedService there.
      # The ref's r.file will be ctrl (absolute), which != svc_path => external ref.
      index = Backpressure::ProjectIndex.new(classes: [entry], files: [ctrl])
      context = Backpressure::Contexts::SourceContext.new(
        source: "class UsedService; def run; end; end",
        file_path: svc_path
      )
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations).to be_empty
    end
  end
end
