# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class OrphanedComponent < Check
        category "DesignSystem"
        severity :warning
        files "app/components/glass_morph/**/*.rb"
        requires :source, :project
        description "Flags GlassMorph components with no external references"

        def check(context)
          index = context.project_index
          component_classes = index.classes_in("app/components/glass_morph/**/*.rb")
          this_file_classes = component_classes.select { |c| c.file == context.file_path }

          this_file_classes.each do |klass|
            refs = index.references_to([klass])
            external_refs = refs.reject { |r| r.file == context.file_path }
            next unless external_refs.empty?

            node = klass.node || OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Component `#{klass.name}` is never referenced outside its own file")
          end
        end
      end
    end
  end
end
