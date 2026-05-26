# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module ToolSafety
        class OverprivilegedToolSet < AiCheck
          category "AI/ToolSafety"
          severity :warning
          files "app/ai/agents/**/*.rb"
          requires :source

          ai_config(provider: :test, temperature: 0, max_tokens: 512,
            schema: { type: "array", items: { type: "object",
              properties: { line: { type: "integer" }, message: { type: "string" } } } })

          prompt_template <<~PROMPT
            Analyze this RAAF agent's tool set. If the agent has tools
            that can write, delete, or modify data but the agent's task
            (based on its system prompt) only requires reading data, flag
            the overprivileged tools. Principle of least privilege.

            Source:
            {{source}}
          PROMPT
        end
      end
    end
  end
end
