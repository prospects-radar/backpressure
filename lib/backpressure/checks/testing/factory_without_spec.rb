# frozen_string_literal: true

module Backpressure
  module Checks
    module Testing
      class FactoryWithoutSpec < Check
        category "Testing"
        severity :info
        files "spec/factories/**/*.rb"
        requires :source, :project

        FACTORY_PATTERN = /factory\s+:(\w+)/

        def check(context)
          context.lines.each_with_index do |line, idx|
            match = line.match(FACTORY_PATTERN)
            next unless match

            factory_name = match[1]
            referenced = context.project_index.files.any? do |f|
              next unless f.match?(%r{spec/.*_spec\.rb\z})
              next unless File.exist?(f)

              File.read(f).include?(factory_name)
            end

            next if referenced

            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            violation(node, "Factory `:#{factory_name}` is never referenced in any spec file")
          end
        end
      end
    end
  end
end
