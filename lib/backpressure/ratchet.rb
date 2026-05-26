# frozen_string_literal: true

module Backpressure
  class Ratchet
    Result = Struct.new(:new_violations, :tampered, keyword_init: true) do
      def pass?
        new_violations.empty? && !tampered
      end

      def tampered?
        tampered
      end
    end

    def initialize(baseline_path:, anti_tamper: true)
      @baseline_path = baseline_path
      @anti_tamper = anti_tamper
    end

    def evaluate(violations)
      baseline = Baseline.load(@baseline_path)
      return Result.new(new_violations: [], tampered: false) if baseline.empty?

      tampered = @anti_tamper && baseline.tampered?(violations)
      new_violations = baseline.new_violations(violations)

      Result.new(new_violations: new_violations, tampered: tampered)
    end

    def update_baseline(violations)
      Baseline.write(violations, path: @baseline_path)
    end
  end
end
