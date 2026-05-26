# frozen_string_literal: true

module Backpressure
  module Corrections
    class Remove < Correction
      def initialize(line:)
        @line = line
      end

      def apply(source)
        lines = source.lines
        lines.delete_at(@line - 1)
        lines.join
      end
    end
  end
end
