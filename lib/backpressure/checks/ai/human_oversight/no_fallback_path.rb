# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module HumanOversight
        class NoFallbackPath < Check
          category "AI/HumanOversight"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/\.run\b/)
            return if context.source.match?(/rescue|fallback|default_response|error_result/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent has no fallback path — failures will surface as raw errors")
          end
        end
      end
    end
  end
end
