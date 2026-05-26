# frozen_string_literal: true

module Backpressure
  module AI
    module Strategies
      class PreFilter
        def initialize(pattern:)
          @pattern = pattern.is_a?(String) ? Regexp.new(pattern) : pattern
        end

        def should_run?(source)
          source.match?(@pattern)
        end
      end
    end
  end
end
