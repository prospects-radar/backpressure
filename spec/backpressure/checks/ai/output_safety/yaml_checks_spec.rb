# frozen_string_literal: true

RSpec.describe "AI/OutputSafety YAML checks" do
  let(:yaml_dir) { File.expand_path("../../../../../checks/yaml/ai", __dir__) }

  %w[hallucination_guard_missing schema_field_coverage].each do |name|
    describe name do
      let(:check_class) { Backpressure::YamlLoader.load(File.join(yaml_dir, "#{name}.check.yml")) }

      it "loads with correct category" do
        expect(check_class.check_category).to eq("AI/OutputSafety")
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
