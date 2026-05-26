# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Observability
        class NoTraceId < Check
          category "AI/Observability"
          severity :info
          files "app/ai/**/*.rb"
          requires :source
          description "Flags agent calls without trace_id or correlation_id"

          def check(context)
            return unless context.source.match?(/\.run\b/)
            return if context.source.match?(/trace_id|correlation_id|request_id/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent calls other agents without passing a trace/correlation ID")
          end
        end
      end
    end
  end
end
