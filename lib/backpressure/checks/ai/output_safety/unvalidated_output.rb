# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module OutputSafety
        class UnvalidatedOutput < Check
          category "AI/OutputSafety"
          severity :error
          files "app/{controllers,services}/**/*.rb"
          requires :ast

          def check(context)
            return unless context.ast
            return unless context.source.match?(/\.run\b/)

            context.ast.each_node(:send) do |node|
              method_name = node.children[1]
              next unless method_name == :run

              receiver = node.children[0]
              next unless receiver

              line_num = node.loc.line
              remaining = context.source.lines[line_num - 1..line_num + 5]&.join || ""
              unless remaining.match?(/\.success\?|\.valid\?|\.errors|validate!/)
                violation(node, "Agent `.run` result used without checking `.success?` or validating output")
              end
            end
          end
        end
      end
    end
  end
end
