# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module DataGovernance
        class ExternalAPIKeyExposure < Check
          category "AI/DataGovernance"
          severity :error
          files "app/ai/**/*.rb"
          requires :source
          description "Flags hardcoded API keys instead of ENV or credentials"

          KEY_PATTERN = /api[_-]?key|secret[_-]?key|access[_-]?token|bearer/i
          ENV_PATTERN = /ENV\[|Rails\.application\.credentials/

          def check(context)
            context.lines.each_with_index do |line, idx|
              next unless line.match?(KEY_PATTERN)
              next if line.match?(ENV_PATTERN)
              next if line.match?(/^\s*#/)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "API key reference that could leak via LLM prompt — use ENV or credentials instead")
            end
          end
        end
      end
    end
  end
end
