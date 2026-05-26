# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Observability
        class AuditTrailMissing < Check
          category "AI/Observability"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source
          description "Flags DB mutations in AI code without audit trail logging"

          MUTATION_PATTERN = /\.save!?|\.update!?|\.create!?|\.destroy!?|\.delete/

          def check(context)
            return unless context.source.match?(MUTATION_PATTERN)
            return if context.source.match?(/audit|log_action|paper_trail|track_change/)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(MUTATION_PATTERN)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Agent mutates DB records without audit trail logging")
            end
          end
        end
      end
    end
  end
end
