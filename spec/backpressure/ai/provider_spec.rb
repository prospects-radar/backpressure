# frozen_string_literal: true

RSpec.describe Backpressure::AI::Provider do
  describe ".for" do
    it "returns a provider instance by name" do
      provider = described_class.for(:test, config: {})
      expect(provider).to be_a(Backpressure::AI::Provider)
    end

    it "raises for unknown provider" do
      expect { described_class.for(:unknown_xyz, config: {}) }
        .to raise_error(Backpressure::Error, /Unknown provider/)
    end
  end

  describe ".register" do
    it "registers a custom provider" do
      custom = Class.new(described_class)
      described_class.register(:custom_test, custom)
      expect(described_class.for(:custom_test, config: {})).to be_a(custom)
    ensure
      described_class.providers.delete(:custom_test)
    end
  end
end

RSpec.describe Backpressure::AI::Providers::Test do
  subject(:provider) { described_class.new(config: {}) }

  it "returns canned responses" do
    result = provider.complete(
      prompt: "test prompt",
      model: "test-model",
      temperature: 0.0,
      max_tokens: 100,
      schema: nil
    )
    expect(result).to eq([])
  end
end
