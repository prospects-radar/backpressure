# frozen_string_literal: true

require "backpressure/checks/hygiene/dead_require"

RSpec.describe Backpressure::Checks::Hygiene::DeadRequire do
  def run_check(source, file_path:, project_files: [])
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    index = Backpressure::ProjectIndex.new(classes: [], files: project_files)
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    check
  end

  it "flags require_relative pointing to nonexistent file" do
    check = run_check(
      'require_relative "nonexistent"',
      file_path: "/tmp/app/models/user.rb",
      project_files: ["/tmp/app/models/user.rb"]
    )
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("nonexistent")
  end

  it "passes when required file exists" do
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.rb")
      dep = File.join(dir, "helper.rb")
      File.write(main, 'require_relative "helper"')
      File.write(dep, "# helper")

      check = run_check(
        File.read(main),
        file_path: main,
        project_files: [main, dep]
      )
      expect(check.violations).to be_empty
    end
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("Hygiene")
    expect(described_class.required_contexts).to include(:project)
  end
end
