# frozen_string_literal: true

module Backpressure
  module Corrections
    class Replace < Correction
      attr_reader :original, :replacement

      def initialize(line:, original:, replacement:)
        @line = line
        @original = original
        @replacement = replacement
      end

      def apply(source)
        lines = source.lines
        lines[@line - 1] = lines[@line - 1].sub(original, replacement)
        lines.join
      end
    end
  end
end
