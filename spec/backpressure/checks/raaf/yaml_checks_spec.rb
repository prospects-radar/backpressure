# frozen_string_literal: true

RSpec.describe "RAAF YAML checks" do
  let(:yaml_dir) { File.expand_path("../../../../checks/yaml/raaf", __dir__) }

  %w[prompt_clarity schema_prompt_mismatch tool_description_quality].each do |name|
    describe name do
      let(:check_class) { Backpressure::YamlLoader.load(File.join(yaml_dir, "#{name}.check.yml")) }

      it "loads with correct category" do
        expect(check_class.check_category).to eq("RAAF")
      end

      it "runs with test provider" do
        context = Backpressure::Contexts::SourceContext.new(
          source: "class MyAgent; end",
          file_path: "app/ai/agents/my_agent.rb"
        )
        instance = check_class.new
        instance.run(context)
        expect(instance.violations).to be_empty
      end
    end
  end
end
