# frozen_string_literal: true

RSpec.describe Backpressure::AI::Strategies::PreFilter do
  it "skips files that don't match the pattern" do
    strategy = described_class.new(pattern: /MUST|SHOULD/)
    expect(strategy.should_run?("class Foo; end")).to be false
  end

  it "runs on files that match" do
    strategy = described_class.new(pattern: /MUST|SHOULD/)
    expect(strategy.should_run?("# MUST return a hash")).to be true
  end
end

RSpec.describe Backpressure::AI::Strategies::Consensus do
  let(:provider) { Backpressure::AI::Providers::Test.new(config: {}) }

  it "runs the check N times and reports majority-agreed violations" do
    call_count = 0
    responses = [
      [{ "line" => 5, "message" => "unclear constraint" }],
      [{ "line" => 5, "message" => "unclear constraint" }, { "line" => 10, "message" => "ambiguous" }],
      [{ "line" => 5, "message" => "unclear constraint" }]
    ]

    strategy = described_class.new(count: 3)
    result = strategy.evaluate do |_attempt|
      r = responses[call_count]
      call_count += 1
      r
    end

    agreed = result.select { |v| v[:agreed] }
    expect(agreed.size).to eq(1)
    expect(agreed.first["line"]).to eq(5)
  end
end
