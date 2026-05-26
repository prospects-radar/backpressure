# frozen_string_literal: true

RSpec.describe Backpressure::AiCheck do
  let(:check_class) do
    Class.new(described_class) do
      category "AI/Test"
      files "**/*.rb"
      requires :source

      def self.name; "TestAiCheck"; end

      ai_config(
        provider: :test,
        model: "test-model",
        temperature: 0.1,
        max_tokens: 100
      )

      prompt_template "Analyze this code: {{source}}"
    end
  end

  it "has ai_settings" do
    expect(check_class.ai_settings[:provider]).to eq(:test)
    expect(check_class.ai_settings[:model]).to eq("test-model")
  end

  it "has a prompt template" do
    expect(check_class.prompt_text).to include("Analyze this code")
  end

  it "runs with the test provider and produces no violations" do
    context = Backpressure::Contexts::SourceContext.new(source: "class Foo; end", file_path: "foo.rb")
    instance = check_class.new
    instance.run(context)
    expect(instance.violations).to be_empty
  end
end
