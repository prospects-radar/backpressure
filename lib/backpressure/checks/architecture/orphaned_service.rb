# frozen_string_literal: true

module Backpressure
  module Checks
    module Architecture
      class OrphanedService < Check
        category "Architecture"
        severity :warning
        files "app/services/**/*.rb"
        requires :source, :project
        description "Flags service classes with no external references"

        def check(context)
          index = context.project_index
          this_classes = index.classes.select { |c| c.file == context.file_path }
          return if this_classes.empty?

          this_classes.each do |klass|
            refs = index.references_to([klass])
            external_refs = refs.reject { |r| r.file == context.file_path }
            next unless external_refs.empty?

            node = klass.node || OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Service `#{klass.name}` is never referenced outside its own file")
          end
        end
      end
    end
  end
end
