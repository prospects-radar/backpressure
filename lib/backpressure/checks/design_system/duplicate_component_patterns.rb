# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class DuplicateComponentPatterns < AiCheck
        category "DesignSystem"
        severity :info
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex, :project
        description "AI check for duplicated component patterns across views"

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
          Analyze this Phlex component for component subtrees that appear
          duplicated. If a group of 3+ components appears in the same
          arrangement elsewhere, suggest extracting a shared organism.

          Only flag HIGH confidence duplications.

          Source:
          {{source}}
        PROMPT
      end
    end
  end
end
