# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module PromptSafety
        class SystemPromptDrift < AiCheck
          category "AI/PromptSafety"
          severity :info
          files "app/ai/**/*.rb"
          requires :source, :project

          ai_config(
            provider: :test,
            temperature: 0,
            max_tokens: 512,
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
            Check if this agent's system prompt is near-identical to another
            agent's system prompt. If >80% of the system prompt text is shared
            with another file, flag it for extraction into a shared base prompt.

            Source:
            {{source}}
          PROMPT
        end
      end
    end
  end
end
