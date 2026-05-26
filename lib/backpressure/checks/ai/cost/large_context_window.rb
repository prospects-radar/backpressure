# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Cost
        class LargeContextWindow < Check
          category "AI/Cost"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source
          description "Flags File.read injected into AI prompts without truncation"

          def check(context)
            return unless context.source.match?(/\.read\b|File\.read|\.body\b/)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(/File\.read|\.read\b.*\.join/)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Large file read into prompt context — consider summarization to reduce token cost")
            end
          end
        end
      end
    end
  end
end
