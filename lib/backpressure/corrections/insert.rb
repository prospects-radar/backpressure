# frozen_string_literal: true

module Backpressure
  module Corrections
    class Insert < Correction
      attr_reader :text, :position

      def initialize(line:, text:, position: :before)
        @line = line
        @text = text
        @position = position
      end

      def apply(source)
        lines = source.lines
        idx = @line - 1
        if position == :before
          lines.insert(idx, text)
        else
          lines.insert(idx + 1, text)
        end
        lines.join
      end
    end
  end
end
