# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module HumanOversight
        class AutonomousStateChange < Check
          category "AI/HumanOversight"
          severity :error
          files "app/ai/**/*.rb"
          requires :source
          description "Flags state mutations without human approval gates"

          STATE_CHANGE = /\.update!?\(.*status|\.transition_to|state_machine|\.save!/

          def check(context)
            return unless context.source.match?(STATE_CHANGE)
            return if context.source.match?(/requires_approval|human_review|approval_gate/)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(STATE_CHANGE)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Agent changes record state without human approval step")
            end
          end
        end
      end
    end
  end
end
