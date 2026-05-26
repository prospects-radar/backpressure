# frozen_string_literal: true

require "backpressure/checks/testing/factory_without_spec"

RSpec.describe Backpressure::Checks::Testing::FactoryWithoutSpec do
  def run_check(source, file_path: "spec/factories/users.rb", index:)
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    check
  end

  it "flags factory not referenced in any spec" do
    index = Backpressure::ProjectIndex.new(classes: [], files: [])
    check = run_check("factory :user do\n  name { 'Test' }\nend", index: index)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include(":user")
  end

  it "passes when factory is referenced in a spec file" do
    Dir.mktmpdir do |dir|
      spec_file = File.join(dir, "spec/models/user_spec.rb")
      FileUtils.mkdir_p(File.dirname(spec_file))
      File.write(spec_file, "let(:user) { create(:user) }")

      index = Backpressure::ProjectIndex.new(classes: [], files: [spec_file])
      check = run_check("factory :user do\n  name { 'Test' }\nend", index: index)
      expect(check.violations).to be_empty
    end
  end

  it "ignores non-spec files in the project index" do
    Dir.mktmpdir do |dir|
      non_spec = File.join(dir, "app/models/user.rb")
      FileUtils.mkdir_p(File.dirname(non_spec))
      File.write(non_spec, "class User; end")

      index = Backpressure::ProjectIndex.new(classes: [], files: [non_spec])
      check = run_check("factory :user do\n  name { 'Test' }\nend", index: index)
      expect(check.violations.size).to eq(1)
    end
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("Testing")
    expect(described_class.check_severity).to eq(:info)
  end
end
