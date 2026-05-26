# frozen_string_literal: true

RSpec.describe "Convention YAML checks" do
  let(:yaml_dir) { File.expand_path("../../../../checks/yaml/convention", __dir__) }

  %w[commented_out_code].each do |name|
    describe name do
      let(:check_class) { Backpressure::YamlLoader.load(File.join(yaml_dir, "#{name}.check.yml")) }

      it "loads with correct category" do
        expect(check_class.check_category).to eq("Convention")
      end

      it "runs with test provider" do
        context = Backpressure::Contexts::SourceContext.new(
          source: "class Foo\n  def bar\n    42\n  end\nend",
          file_path: "app/models/foo.rb"
        )
        instance = check_class.new
        instance.run(context)
        expect(instance.violations).to be_empty
      end
    end
  end
end
