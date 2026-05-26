# frozen_string_literal: true

RSpec.describe "AI/Cost YAML checks" do
  let(:yaml_dir) { File.expand_path("../../../../../checks/yaml/ai", __dir__) }

  %w[expensive_model_for_simple_task].each do |name|
    describe name do
      let(:check_class) { Backpressure::YamlLoader.load(File.join(yaml_dir, "#{name}.check.yml")) }

      it "loads with correct category" do
        expect(check_class.check_category).to eq("AI/Cost")
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
