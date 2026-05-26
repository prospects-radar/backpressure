# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Cost
        class UnboundedRetryLoop < Check
          category "AI/Cost"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          RETRY_PATTERN = /\bretry\b/
          MAX_PATTERN = /max_attempts|max_retries|retry_count|attempts\s*[<>=]/

          def check(context)
            return unless context.source.match?(RETRY_PATTERN)
            return if context.source.match?(MAX_PATTERN)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(RETRY_PATTERN)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "`retry` without max attempt cap — potential runaway cost")
            end
          end
        end
      end
    end
  end
end
