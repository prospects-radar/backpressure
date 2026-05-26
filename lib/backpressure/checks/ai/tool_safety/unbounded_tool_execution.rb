# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module ToolSafety
        class UnboundedToolExecution < Check
          category "AI/ToolSafety"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/build_tool|register_tool|def execute/)
            return if context.source.match?(/timeout|Timeout\.timeout|with_timeout/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Tool execution without timeout — agent could hang indefinitely")
          end
        end
      end
    end
  end
end
