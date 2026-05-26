# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Cost
        class MissingCacheability < Check
          category "AI/Cost"
          severity :info
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/temperature:\s*0(?!\.\d)/)
            return if context.source.match?(/cache|memoize|Rails\.cache/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Deterministic prompt (temperature: 0) without caching — repeated calls waste tokens")
          end
        end
      end
    end
  end
end
