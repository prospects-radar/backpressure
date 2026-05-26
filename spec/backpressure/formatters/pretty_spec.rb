# frozen_string_literal: true

RSpec.describe Backpressure::Formatters::Pretty do
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
      ),
      Backpressure::Violation.new(
        check_name: "NoDirectAR",
        category: "Architecture",
        severity: :warning,
        message: "Use a service object",
        file: "app/controllers/bar.rb",
        line: 10,
        column: 3
      )
    ]
  end

  describe "#format" do
    it "includes file path and line" do
      output = formatter.format(violations)
      expect(output).to include("app/controllers/foo.rb:42:5")
    end

    it "includes the check name" do
      output = formatter.format(violations)
      expect(output).to include("NoDirectAR")
    end

    it "includes the message" do
      output = formatter.format(violations)
      expect(output).to include("Use a service object")
    end

    it "shows auto-correctable marker" do
      output = formatter.format(violations)
      expect(output).to include("auto-correctable")
    end

    it "includes a summary line" do
      output = formatter.format(violations)
      expect(output).to include("2 violation(s)")
    end

    it "returns clean output for zero violations" do
      output = formatter.format([])
      expect(output).to include("No violations")
    end
  end
end
