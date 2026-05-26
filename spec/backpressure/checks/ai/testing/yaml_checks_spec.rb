# frozen_string_literal: true

RSpec.describe "AI/Testing YAML checks" do
  let(:yaml_dir) { File.expand_path("../../../../../checks/yaml/ai", __dir__) }

  %w[no_edge_case_tests].each do |name|
    describe name do
      let(:check_class) { Backpressure::YamlLoader.load(File.join(yaml_dir, "#{name}.check.yml")) }

      it "loads with correct category" do
        expect(check_class.check_category).to eq("AI/Testing")
      end

      it "runs with test provider" do
        context = Backpressure::Contexts::SourceContext.new(
          source: "RSpec.describe MyAgent do; it 'works' do; end; end",
          file_path: "spec/ai/agents/my_agent_spec.rb"
        )
        instance = check_class.new
        instance.run(context)
        expect(instance.violations).to be_empty
      end
    end
  end
end
