# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::YamlLoader do
  let(:tmpdir) { Dir.mktmpdir("bp_yaml") }

  after { FileUtils.remove_entry(tmpdir) }

  it "loads a YAML check file and returns a check class" do
    yaml_path = File.join(tmpdir, "test_check.check.yml")
    File.write(yaml_path, <<~YAML)
      name: TestYamlCheck
      category: AI/Test
      files: "**/*.rb"
      requires: source
      severity: warning
      ai:
        provider: test
        model: test-model
        temperature: 0.1
        max_tokens: 100
      prompt: "Check this code for issues"
    YAML

    klass = described_class.load(yaml_path)

    expect(klass.check_name).to eq("TestYamlCheck")
    expect(klass.check_category).to eq("AI/Test")
    expect(klass.check_severity).to eq(:warning)
    expect(klass.file_glob).to eq("**/*.rb")
    expect(klass.ai_settings[:provider]).to eq(:test)
    expect(klass.prompt_text).to eq("Check this code for issues")
  end

  it "loads all YAML checks from a directory" do
    File.write(File.join(tmpdir, "a.check.yml"), <<~YAML)
      name: CheckA
      category: Test
      files: "**/*.rb"
      requires: source
      ai:
        provider: test
        model: m
      prompt: "test"
    YAML

    File.write(File.join(tmpdir, "b.check.yml"), <<~YAML)
      name: CheckB
      category: Test
      files: "**/*.rb"
      requires: source
      ai:
        provider: test
        model: m
      prompt: "test"
    YAML

    classes = described_class.load_all(tmpdir)
    expect(classes.map(&:check_name)).to contain_exactly("CheckA", "CheckB")
  end
end
