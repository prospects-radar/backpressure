# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module DataGovernance
        class SensitiveDataInPrompt < AiCheck
          category "AI/DataGovernance"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          ai_config(provider: :test, temperature: 0, max_tokens: 512,
            schema: { type: "array", items: { type: "object",
              properties: { line: { type: "integer" }, message: { type: "string" } } } })

          prompt_template <<~PROMPT
            Analyze this AI agent for sensitive data exposure.

            Flag if PII fields (email, phone, ssn, address, date_of_birth,
            salary, credit_card) from model associations are loaded into
            the prompt context without field filtering (e.g., `.select` or
            `.pluck` to pick only needed fields).

            Source:
            {{source}}
          PROMPT
        end
      end
    end
  end
end
