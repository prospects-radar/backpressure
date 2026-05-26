# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Cost
        class NoMaxTokensLimit < Check
          category "AI/Cost"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return if context.source.match?(/max_tokens/)
            return unless context.source.match?(/\.complete\b|\.chat\b|\.run\b/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "AI call without `max_tokens` — unbounded response cost")
          end
        end
      end
    end
  end
end
