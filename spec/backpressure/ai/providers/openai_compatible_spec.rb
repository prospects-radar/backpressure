# frozen_string_literal: true

RSpec.describe Backpressure::AI::Providers::OpenAiCompatible do
  let(:config) do
    {
      "openai_compatible" => {
        "url" => "http://localhost:11434/v1",
        "model" => "qwen2.5-coder"
      }
    }
  end

  subject(:provider) { described_class.new(config: config) }

  let(:violations) { [{ "line" => 5, "message" => "Potential injection" }] }

  let(:success_body) do
    {
      "choices" => [{
        "message" => { "content" => JSON.generate(violations) }
      }]
    }.to_json
  end

  def stub_http(response_code: "200", response_body: success_body)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)

    response = instance_double(Net::HTTPOK, code: response_code, body: response_body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(response_code == "200")
    allow(http).to receive(:request).and_return(response)

    http
  end

  describe "#complete" do
    it "sends a POST to the chat completions endpoint and returns parsed violations" do
      http = stub_http

      result = provider.complete(
        prompt: "Analyze this code",
        model: "qwen2.5-coder",
        temperature: 0,
        max_tokens: 1024,
        schema: { type: "array", items: { type: "object", properties: { line: { type: "integer" }, message: { type: "string" } } } }
      )

      expect(result).to eq(violations)
      expect(http).to have_received(:request) do |req|
        body = JSON.parse(req.body)
        expect(body["model"]).to eq("qwen2.5-coder")
        expect(body["messages"].length).to eq(2)
        expect(body["messages"][1]["content"]).to eq("Analyze this code")
        expect(body["response_format"]["type"]).to eq("json_schema")
      end
    end

    it "uses the config model when none specified" do
      http = stub_http

      provider.complete(prompt: "test", model: nil, temperature: 0, max_tokens: 1024, schema: nil)

      expect(http).to have_received(:request) do |req|
        body = JSON.parse(req.body)
        expect(body["model"]).to eq("qwen2.5-coder")
      end
    end

    it "omits response_format when schema is nil" do
      http = stub_http

      provider.complete(prompt: "test", model: "m", temperature: 0, max_tokens: 1024, schema: nil)

      expect(http).to have_received(:request) do |req|
        body = JSON.parse(req.body)
        expect(body).not_to have_key("response_format")
      end
    end

    it "sets Authorization header when api_key is configured" do
      config["openai_compatible"]["api_key"] = "sk-test-123"
      http = stub_http

      provider.complete(prompt: "test", model: "m", temperature: 0, max_tokens: 1024, schema: nil)

      expect(http).to have_received(:request) do |req|
        expect(req["Authorization"]).to eq("Bearer sk-test-123")
      end
    end

    it "expands env var references in api_key" do
      config["openai_compatible"]["api_key"] = "${TEST_BP_KEY}"
      ENV["TEST_BP_KEY"] = "sk-from-env"
      http = stub_http

      provider.complete(prompt: "test", model: "m", temperature: 0, max_tokens: 1024, schema: nil)

      expect(http).to have_received(:request) do |req|
        expect(req["Authorization"]).to eq("Bearer sk-from-env")
      end
    ensure
      ENV.delete("TEST_BP_KEY")
    end

    it "raises on HTTP error" do
      stub_http(response_code: "500", response_body: "Internal Server Error")

      expect {
        provider.complete(prompt: "test", model: "m", temperature: 0, max_tokens: 1024, schema: nil)
      }.to raise_error(Backpressure::Error, /API error \(500\)/)
    end

    it "raises when response has no content" do
      stub_http(response_body: { "choices" => [{ "message" => {} }] }.to_json)

      expect {
        provider.complete(prompt: "test", model: "m", temperature: 0, max_tokens: 1024, schema: nil)
      }.to raise_error(Backpressure::Error, /No content/)
    end

    it "raises on malformed JSON in content" do
      stub_http(response_body: { "choices" => [{ "message" => { "content" => "not json" } }] }.to_json)

      expect {
        provider.complete(prompt: "test", model: "m", temperature: 0, max_tokens: 1024, schema: nil)
      }.to raise_error(Backpressure::Error, /Failed to parse/)
    end
  end

  describe "registration" do
    it "is registered as :openai_compatible" do
      p = Backpressure::AI::Provider.for(:openai_compatible, config: config)
      expect(p).to be_a(described_class)
    end
  end

  describe "missing url" do
    let(:config) { { "openai_compatible" => {} } }

    it "raises when url is not configured" do
      expect {
        provider.complete(prompt: "test", model: "m", temperature: 0, max_tokens: 1024, schema: nil)
      }.to raise_error(Backpressure::Error, /url.*required/i)
    end
  end
end
