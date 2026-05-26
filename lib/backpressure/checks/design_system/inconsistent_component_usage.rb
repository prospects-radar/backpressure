# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class InconsistentComponentUsage < AiCheck
        category "DesignSystem"
        severity :warning
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex, :project
        description "AI check for inconsistent usage of design system components"

        ai_config(
          provider: :test,
          temperature: 0,
          max_tokens: 1024,
          schema: {
            type: "array",
            items: {
              type: "object",
              properties: {
                line: { type: "integer" },
                message: { type: "string" }
              }
            }
          }
        )

        prompt_template <<~PROMPT
          You are a design system auditor. Analyze this Phlex component for
          inconsistent component usage patterns compared to the project norm.

          Flag components used with unusual kwargs that differ from the majority
          pattern across the codebase. Only report HIGH confidence findings.

          Source:
          {{source}}
        PROMPT
      end
    end
  end
end
