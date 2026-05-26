# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Observability
        class NoLogging < Check
          category "AI/Observability"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return if context.source.match?(/RAAF\.logger|Rails\.logger|logger\./)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent has no logging — AI decisions will be untraceable")
          end
        end
      end
    end
  end
end
