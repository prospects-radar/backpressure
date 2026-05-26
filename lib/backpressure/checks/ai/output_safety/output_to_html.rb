# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module OutputSafety
        class OutputToHTML < Check
          category "AI/OutputSafety"
          severity :error
          files "app/{views,components}/**/*.rb"
          requires :source
          description "Flags raw() and html_safe on potentially AI-generated content"

          RAW_OUTPUT_PATTERN = /raw\s*\(|html_safe|==\s/

          def check(context)
            context.lines.each_with_index do |line, idx|
              next unless line.match?(RAW_OUTPUT_PATTERN)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Unescaped output (`raw`, `html_safe`, or `==`) — potential XSS if content comes from LLM")
            end
          end
        end
      end
    end
  end
end
