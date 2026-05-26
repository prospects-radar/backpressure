# frozen_string_literal: true

module Backpressure
  class AiCheck < Check
    class << self
      def ai_config(settings = nil)
        if settings
          @ai_settings = settings
        else
          @ai_settings
        end
      end

      def ai_settings
        @ai_settings || (superclass.respond_to?(:ai_settings) ? superclass.ai_settings : {})
      end

      def prompt_template(text = nil)
        if text
          @prompt_text = text
        else
          @prompt_text
        end
      end

      def prompt_text
        @prompt_text || (superclass.respond_to?(:prompt_text) ? superclass.prompt_text : nil)
      end
    end

    def check(context)
      settings = self.class.ai_settings
      provider = AI::Provider.for(settings[:provider], config: Backpressure.configuration.ai_config)

      prompt = render_prompt(context)
      results = provider.complete(
        prompt: prompt,
        model: settings[:model],
        temperature: settings.fetch(:temperature, 0.1),
        max_tokens: settings.fetch(:max_tokens, 1024),
        schema: settings[:schema]
      )

      interpret(results, context)
    end

    def interpret(results, context)
      Array(results).each do |r|
        line = r["line"] || r[:line] || 0
        message = r["message"] || r[:message] || "AI violation"
        node = OpenStruct.new(loc: OpenStruct.new(line: line, column: 0))
        violation(node, message)
      end
    end

    private

    def render_prompt(context)
      template = self.class.prompt_text || ""
      template.sub("{{source}}") { context.source }
    end
  end
end
