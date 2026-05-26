# frozen_string_literal: true

RSpec.describe "AIInventedPatterns YAML check" do
  let(:yaml_path) do
    File.expand_path("../../../../checks/yaml/design_system/ai_invented_patterns.check.yml", __dir__)
  end

  let(:check_class) { Backpressure::YamlLoader.load(yaml_path) }

  it "loads from YAML with correct metadata" do
    expect(check_class.check_name).to eq("AIInventedPatterns")
    expect(check_class.check_category).to eq("DesignSystem")
    expect(check_class.check_severity).to eq(:warning)
  end

  it "runs with test provider and produces no violations" do
    context = Backpressure::Contexts::SourceContext.new(
      source: "class Foo; end",
      file_path: "app/views/glass_morph/test.rb"
    )
    instance = check_class.new
    instance.run(context)
    expect(instance.violations).to be_empty
  end
end
