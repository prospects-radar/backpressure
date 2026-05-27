# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class UnusedComponentSlots < Check
        category "DesignSystem"
        severity :warning
        files "app/components/glass_morph/**/*.rb"
        requires :source, :project
        description "Flags components defining yield slots that no caller uses"

        YIELD_PATTERN = /\byield\b/

        def check(context)
          return unless context.source.match?(YIELD_PATTERN)

          index = context.project_index
          component_name = File.basename(context.file_path, ".rb").split("_").map(&:capitalize).join

          escaped = Regexp.escape(component_name)
          block_do = /#{escaped}\s*[\(].*\bdo\b/m
          block_brace = /#{escaped}\s*\{/

          has_block_caller = index.files.any? do |file|
            next if file == context.file_path

            source = index.source_for(file)
            next unless source

            source.match?(block_do) || source.match?(block_brace)
          end

          return if has_block_caller

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "`#{component_name}` defines yield slots but no caller passes a block")
        end
      end
    end
  end
end
