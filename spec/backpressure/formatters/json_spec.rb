# frozen_string_literal: true

require "json"

RSpec.describe Backpressure::Formatters::Json do
  subject(:formatter) { described_class.new }

  let(:violations) do
    [
      Backpressure::Violation.new(
        check_name: "NoDirectAR",
        category: "Architecture",
        severity: :error,
        message: "Use a service object",
        file: "app/controllers/foo.rb",
        line: 42,
        column: 5,
        auto_correctable: true
      )
    ]
  end

  describe "#format" do
    it "returns valid JSON" do
      output = formatter.format(violations)
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
    end

    it "includes all violation fields" do
      output = formatter.format(violations)
      parsed = JSON.parse(output)
      v = parsed.first

      expect(v["check_name"]).to eq("NoDirectAR")
      expect(v["category"]).to eq("Architecture")
      expect(v["severity"]).to eq("error")
      expect(v["message"]).to eq("Use a service object")
      expect(v["file"]).to eq("app/controllers/foo.rb")
      expect(v["line"]).to eq(42)
      expect(v["column"]).to eq(5)
      expect(v["auto_correctable"]).to be true
    end

    it "returns empty array for no violations" do
      output = formatter.format([])
      expect(JSON.parse(output)).to eq([])
    end
  end
end
