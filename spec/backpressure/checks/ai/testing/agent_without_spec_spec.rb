# frozen_string_literal: true

require "backpressure/checks/ai/testing/agent_without_spec"

RSpec.describe Backpressure::Checks::AI::Testing::AgentWithoutSpec do
  def run_check(source, file_path:, index:)
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    check
  end

  it "flags agent with no corresponding spec in project index" do
    index = Backpressure::ProjectIndex.new(classes: [], files: [])
    check = run_check(
      "class MyAgent; end",
      file_path: "app/ai/agents/my_agent.rb",
      index: index
    )
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("spec/ai/agents/my_agent_spec.rb")
  end

  it "passes when spec file is in project index" do
    index = Backpressure::ProjectIndex.new(classes: [], files: ["spec/ai/agents/my_agent_spec.rb"])
    check = run_check(
      "class MyAgent; end",
      file_path: "app/ai/agents/my_agent.rb",
      index: index
    )
    expect(check.violations).to be_empty
  end

  it "passes when spec file exists on disk" do
    Dir.mktmpdir do |dir|
      spec_file = File.join(dir, "spec/ai/agents/my_agent_spec.rb")
      FileUtils.mkdir_p(File.dirname(spec_file))
      File.write(spec_file, "RSpec.describe MyAgent; end")

      index = Backpressure::ProjectIndex.new(classes: [], files: [])
      context = Backpressure::Contexts::SourceContext.new(
        source: "class MyAgent; end",
        file_path: File.join(dir, "app/ai/agents/my_agent.rb")
      )
      context.define_singleton_method(:project_index) { index }
      check = described_class.new
      check.run(context)
      expect(check.violations).to be_empty
    end
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("AI/Testing")
    expect(described_class.check_severity).to eq(:warning)
  end
end
