# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class ComponentCoverageDrift < Check
        category "DesignSystem"
        severity :error
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex
        ratchet :strict
        description "Tracks design system coverage percentage per Phlex view"

        def check(context)
          skip("No view_template found") unless context.tree

          total = 0
          raw = 0
          context.tree.each_node do |node|
            total += 1
            raw += 1 if context.raw_html_elements.include?(node.name)
          end

          return if total.zero?

          coverage = ((total - raw).to_f / total * 100).round(1)
          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "Design system coverage: #{coverage}% (#{raw}/#{total} raw HTML nodes)")
        end
      end
    end
  end
end
