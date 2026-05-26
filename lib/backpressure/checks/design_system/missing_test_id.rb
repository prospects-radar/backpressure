# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class MissingTestId < Check
        category "DesignSystem"
        severity :warning
        files "app/components/glass_morph/organisms/**/*.rb"
        requires :source, :project
        description "Flags organisms used in Cucumber but missing tid() test IDs"

        TID_PATTERN = /\btid\s*\(/

        def check(context)
          return if context.source.match?(TID_PATTERN)

          component_name = File.basename(context.file_path, ".rb")
          index = context.project_index
          referenced_in_cucumber = index.files.any? do |f|
            next unless f.end_with?("_steps.rb") || f.end_with?(".feature")
            next unless File.exist?(f)

            File.read(f).include?(component_name)
          end

          return unless referenced_in_cucumber

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "Organism `#{component_name}` is referenced in Cucumber but has no `tid()` test ID")
        end
      end
    end
  end
end
