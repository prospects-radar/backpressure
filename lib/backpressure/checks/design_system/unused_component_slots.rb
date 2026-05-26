# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class UnusedComponentSlots < Check
        category "DesignSystem"
        severity :warning
        files "app/components/glass_morph/**/*.rb"
        requires :source, :project

        YIELD_PATTERN = /\byield\b/

        def check(context)
          return unless context.source.match?(YIELD_PATTERN)

          index = context.project_index
          component_name = File.basename(context.file_path, ".rb").split("_").map(&:capitalize).join

          has_block_caller = index.files.any? do |file|
            next if file == context.file_path
            next unless File.exist?(file)

            source = File.read(file)
            source.match?(/#{component_name}\s*[\(].*\bdo\b/m) || source.match?(/#{component_name}\s*\{/)
          end

          return if has_block_caller

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "`#{component_name}` defines yield slots but no caller passes a block")
        end
      end
    end
  end
end
