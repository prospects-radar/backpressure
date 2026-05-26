# frozen_string_literal: true

RSpec.describe Backpressure::Runner do
  let(:config) { Backpressure::Configuration.new }
  let(:registry) { Backpressure::CheckRegistry.new }
  subject(:runner) { described_class.new(config: config, registry: registry) }

  let(:passing_check) do
    Class.new(Backpressure::Check) do
      files "**/*.rb"
      requires :source
      def self.name; "PassingCheck"; end
      def check(context); end
    end
  end

  let(:failing_check) do
    Class.new(Backpressure::Check) do
      files "**/*.rb"
      requires :source
      severity :error
      def self.name; "FailingCheck"; end
      def check(context)
        violation(OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0)), "Something is wrong")
      end
    end
  end

  before do
    registry.register(passing_check)
    registry.register(failing_check)
  end

  describe "#run" do
    it "returns results with violations" do
      tmpfile = Tempfile.new(["test", ".rb"])
      tmpfile.write("class Foo; end")
      tmpfile.close

      result = runner.run(files: [tmpfile.path])

      expect(result.violations.size).to eq(1)
      expect(result.violations.first.check_name).to eq("FailingCheck")
    ensure
      tmpfile.unlink
    end

    it "filters by --only check name" do
      tmpfile = Tempfile.new(["test", ".rb"])
      tmpfile.write("class Foo; end")
      tmpfile.close

      result = runner.run(files: [tmpfile.path], only: ["PassingCheck"])
      expect(result.violations).to be_empty
    ensure
      tmpfile.unlink
    end

    it "skips disabled checks" do
      config = Backpressure::Configuration.from_hash(
        "checks" => { "FailingCheck" => { "enabled" => false } }
      )
      runner = described_class.new(config: config, registry: registry)

      tmpfile = Tempfile.new(["test", ".rb"])
      tmpfile.write("class Foo; end")
      tmpfile.close

      result = runner.run(files: [tmpfile.path])
      expect(result.violations).to be_empty
    ensure
      tmpfile.unlink
    end
  end

  describe "Backpressure::Runner::Result" do
    it "reports success when no error violations" do
      result = described_class::Result.new(violations: [], skipped: [])
      expect(result.success?).to be true
    end

    it "reports failure when error violations exist" do
      v = Backpressure::Violation.new(
        check_name: "X", message: "m", file: "f.rb", line: 1, severity: :error
      )
      result = described_class::Result.new(violations: [v], skipped: [])
      expect(result.success?).to be false
    end
  end
end
