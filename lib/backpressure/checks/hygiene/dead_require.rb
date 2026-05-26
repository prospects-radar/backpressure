# frozen_string_literal: true

module Backpressure
  module Checks
    module Hygiene
      class DeadRequire < Check
        category "Hygiene"
        severity :warning
        files "**/*.rb"
        requires :source, :project
        description "Flags require_relative pointing to nonexistent files"

        REQUIRE_RELATIVE_PATTERN = /^\s*require_relative\s+["']([^"']+)["']/

        def check(context)
          dir = File.dirname(context.file_path)

          context.lines.each_with_index do |line, idx|
            match = line.match(REQUIRE_RELATIVE_PATTERN)
            next unless match

            relative_path = match[1]
            resolved = File.expand_path("#{relative_path}.rb", dir)

            unless File.exist?(resolved)
              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "require_relative \"#{relative_path}\" — file not found at #{resolved}")
            end
          end
        end
      end
    end
  end
end
