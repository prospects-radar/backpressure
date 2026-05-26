# frozen_string_literal: true

require "backpressure/checks/architecture/service_fan_out"

RSpec.describe Backpressure::Checks::Architecture::ServiceFanOut do
  def make_service_entry(name, file_path)
    Backpressure::ProjectIndex::ClassEntry.new(
      name: name,
      file: file_path,
      node: nil,
      superclass_name: nil
    )
  end

  it "flags service calling too many other services" do
    Dir.mktmpdir do |dir|
      main_svc = File.join(dir, "app/services/orchestrator.rb")
      FileUtils.mkdir_p(File.dirname(main_svc))

      # Create 6 dependency service entries with paths containing "app/services"
      dep_entries = (1..6).map do |i|
        svc_path = File.join(dir, "app/services/svc#{i}.rb")
        File.write(svc_path, "class Svc#{i}; def run; end; end")
        make_service_entry("Svc#{i}", svc_path)
      end

      calls = (1..6).map { |i| "Svc#{i}.run" }.join("; ")
      File.write(main_svc, "class Orchestrator; def run; #{calls}; end; end")

      orchestrator_entry = make_service_entry("Orchestrator", main_svc)
      all_entries = dep_entries + [orchestrator_entry]
      index = Backpressure::ProjectIndex.new(classes: all_entries, files: [main_svc])

      context = Backpressure::Contexts::AstContext.new(source: File.read(main_svc), file_path: main_svc)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations.size).to eq(1)
      expect(check.violations.first.message).to include("6")
    end
  end

  it "passes when under the limit" do
    Dir.mktmpdir do |dir|
      svc1 = File.join(dir, "app/services/svc1.rb")
      main = File.join(dir, "app/services/main.rb")
      FileUtils.mkdir_p(File.dirname(svc1))
      File.write(svc1, "class Svc1; end")
      File.write(main, "class Main; def run; Svc1.run; end; end")

      entry_svc1 = make_service_entry("Svc1", svc1)
      entry_main = make_service_entry("Main", main)
      index = Backpressure::ProjectIndex.new(classes: [entry_svc1, entry_main], files: [svc1, main])

      context = Backpressure::Contexts::AstContext.new(source: File.read(main), file_path: main)
      context.define_singleton_method(:project_index) { index }

      check = described_class.new
      check.run(context)
      expect(check.violations).to be_empty
    end
  end
end
