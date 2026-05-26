# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Testing
        class DeterminismUntested < Check
          category "AI/Testing"
          severity :info
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/temperature:\s*0(?:[^\d.]|$)/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent uses temperature: 0 — spec should assert deterministic output on identical input")
          end
        end
      end
    end
  end
end
