# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::Contexts::GroupContext do
  let(:tmpdir) { Dir.mktmpdir("bp_group") }

  after { FileUtils.remove_entry(tmpdir) }

  it "provides access to grouped files by role" do
    agent_path = File.join(tmpdir, "agent.rb")
    prompt_path = File.join(tmpdir, "prompt.rb")
    File.write(agent_path, "class Agent; end")
    File.write(prompt_path, "class Prompt; end")

    roles = { agent: agent_path, prompt: prompt_path }
    context = described_class.new(roles: roles, primary_role: :agent)

    expect(context.file_path).to eq(agent_path)
    expect(context.group[:agent]).to be_a(Backpressure::Contexts::SourceContext)
    expect(context.group[:prompt]).to be_a(Backpressure::Contexts::SourceContext)
    expect(context.group[:agent].source).to eq("class Agent; end")
  end

  it "handles missing companion files" do
    agent_path = File.join(tmpdir, "agent.rb")
    File.write(agent_path, "class Agent; end")

    roles = { agent: agent_path, prompt: File.join(tmpdir, "missing.rb") }
    context = described_class.new(roles: roles, primary_role: :agent)

    expect(context.group[:agent]).to be_a(Backpressure::Contexts::SourceContext)
    expect(context.group[:prompt]).to be_nil
  end
end
