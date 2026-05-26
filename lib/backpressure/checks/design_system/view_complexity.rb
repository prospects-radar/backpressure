# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class ViewComplexity < Check
        category "DesignSystem"
        severity :warning
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex

        MAX_COMPONENTS = 15

        def check(context)
          skip("No view_template found") unless context.tree

          count = context.tree.each_node.count
          return if count <= MAX_COMPONENTS

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "View renders #{count} components (max #{MAX_COMPONENTS}) — consider splitting")
        end
      end
    end
  end
end
