# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module PromptSafety
        class NoInputSanitization < Check
          category "AI/PromptSafety"
          severity :error
          files "app/ai/**/*.rb"
          requires :ast
          description "Flags string interpolation in user-facing prompt methods"

          def check(context)
            return unless context.ast

            context.ast.each_node(:def) do |def_node|
              next unless def_node.children[0] == :user

              body = def_node.children[2]
              next unless body

              body.each_node(:dstr) do |node|
                violation(node, "String interpolation in `def user` — user data may reach prompt unsanitized")
              end
            end
          end
        end
      end
    end
  end
end
