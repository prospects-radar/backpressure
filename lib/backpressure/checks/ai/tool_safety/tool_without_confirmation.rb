# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module ToolSafety
        class ToolWithoutConfirmation < Check
          category "AI/ToolSafety"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          DESTRUCTIVE = /delete|destroy|remove|send_email|send_notification|transfer|publish/i

          def check(context)
            return unless context.source.match?(DESTRUCTIVE)
            return if context.source.match?(/confirm|approve|human_review|requires_approval/)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(DESTRUCTIVE)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Destructive tool operation without human-in-the-loop confirmation gate")
            end
          end
        end
      end
    end
  end
end
