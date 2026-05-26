# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class ComponentCatalogEnforcement < Check
        category "DesignSystem"
        severity :error
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex, :project
        description "Flags raw HTML when a matching design system component exists"

        def check(context)
          skip("No view_template found") unless context.tree

          catalog = build_catalog(context.project_index)
          return if catalog.empty?

          context.tree.each_node do |node|
            element_name = node.name.to_s.downcase
            next unless context.raw_html_elements.include?(node.name)

            replacement = catalog[element_name]
            next unless replacement

            src = node.source_node || OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(src, "Raw `#{node.name}` — use `#{replacement}` instead")
          end
        end

        private

        def build_catalog(index)
          catalog = {}
          atom_glob = "app/components/glass_morph/{atoms,molecules}/**/*.rb"
          index.classes_in(atom_glob).each do |entry|
            component_name = entry.name.split("::").last
            html_equiv = component_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
            catalog[html_equiv] = component_name
          end
          catalog
        end
      end
    end
  end
end
