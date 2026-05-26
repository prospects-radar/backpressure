# frozen_string_literal: true

RSpec.describe "AI/PromptSafety YAML checks" do
  let(:yaml_dir) { File.expand_path("../../../../../checks/yaml/ai", __dir__) }

  %w[prompt_injection_surface pii_in_system_prompt prompt_leakage_risk].each do |name|
    describe name do
      let(:check_class) { Backpressure::YamlLoader.load(File.join(yaml_dir, "#{name}.check.yml")) }

      it "loads with correct category" do
        expect(check_class.check_category).to eq("AI/PromptSafety")
      end

      it "runs with test provider" do
        context = Backpressure::Contexts::SourceContext.new(source: "class Foo; end", file_path: "app/ai/test.rb")
        instance = check_class.new
        instance.run(context)
        expect(instance.violations).to be_empty
      end
    end
  end
end
