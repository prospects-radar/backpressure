# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module OutputSafety
        class OutputToSQL < Check
          category "AI/OutputSafety"
          severity :error
          files "app/**/*.rb"
          requires :ast
          description "Flags string interpolation in SQL query methods"

          QUERY_METHODS = %i[where find_by select joins order group having].freeze

          def check(context)
            return unless context.ast
            context.ast.each_node(:send) do |node|
              method_name = node.children[1]
              next unless QUERY_METHODS.include?(method_name)

              args = node.children[2..]
              args&.each do |arg|
                next unless arg.is_a?(RuboCop::AST::Node)

                if arg.type == :dstr
                  violation(node, "String interpolation in `#{method_name}` — potential SQL injection via LLM output")
                end
              end
            end
          end
        end
      end
    end
  end
end
