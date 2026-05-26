# frozen_string_literal: true

require "backpressure/checks/architecture/circular_service_dependency"

RSpec.describe Backpressure::Checks::Architecture::CircularServiceDependency do
  def make_service_entry(name, real_file_path)
    Backpressure::ProjectIndex::ClassEntry.new(
      name: name,
      file: real_file_path,
      node: nil,
      superclass_name: nil
    )
  end

  it "flags circular dependencies between services" do
    Dir.mktmpdir do |dir|
      svc_a = File.join(dir, "app/services/a_service.rb")
      svc_b = File.join(dir, "app/services/b_service.rb")
      FileUtils.mkdir_p(File.dirname(svc_a))
      File.write(svc_a, "class AService; def run; BService.run; end; end")
      File.write(svc_b, "class BService; def run; AService.run; end; end")

      entry_a = make_service_entry("AService", svc_a)
      entry_b = make_service_entry("BService", svc_b)
      index = Backpressure::ProjectIndex.new(classes: [entry_a, entry_b], files: [svc_a, svc_b])

      context = Backpressure::Contexts::AstContext.new(source: File.read(svc_a), file_path: svc_a)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations.size).to eq(1)
      expect(check.violations.first.message).to include("Circular")
      expect(check.violations.first.message).to include("AService")
      expect(check.violations.first.message).to include("BService")
    end
  end

  it "passes when no circular dependency exists" do
    Dir.mktmpdir do |dir|
      svc_a = File.join(dir, "app/services/a_service.rb")
      svc_b = File.join(dir, "app/services/b_service.rb")
      FileUtils.mkdir_p(File.dirname(svc_a))
      File.write(svc_a, "class AService; def run; BService.run; end; end")
      File.write(svc_b, "class BService; def run; 'done'; end; end")

      entry_a = make_service_entry("AService", svc_a)
      entry_b = make_service_entry("BService", svc_b)
      index = Backpressure::ProjectIndex.new(classes: [entry_a, entry_b], files: [svc_a, svc_b])

      context = Backpressure::Contexts::AstContext.new(source: File.read(svc_a), file_path: svc_a)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations).to be_empty
    end
  end
end
