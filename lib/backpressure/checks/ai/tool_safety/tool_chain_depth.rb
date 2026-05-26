# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module ToolSafety
        class ToolChainDepth < Check
          category "AI/ToolSafety"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source
          description "Flags RAAF pipelines exceeding maximum operator depth"

          MAX_DEPTH = 5

          def check(context)
            return unless context.source.match?(/Pipeline|>>/)

            agent_calls = context.source.scan(/>>/).size + 1
            return if agent_calls <= MAX_DEPTH

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Pipeline chains #{agent_calls} agents (max #{MAX_DEPTH}) — increases hallucination compounding risk")
          end
        end
      end
    end
  end
end
