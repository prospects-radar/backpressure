# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Observability
        class SilentFailure < Check
          category "AI/Observability"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            context.lines.each_with_index do |line, idx|
              next unless line.match?(/rescue\b/)

              remaining = context.lines[idx + 1..idx + 3]&.join || ""
              next if remaining.match?(/log|raise|notify|error_result/)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Rescue block without logging or re-raising — silent failure")
            end
          end
        end
      end
    end
  end
end
