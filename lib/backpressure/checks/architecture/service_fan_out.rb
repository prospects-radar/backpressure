# frozen_string_literal: true

module Backpressure
  module Checks
    module Architecture
      class ServiceFanOut < Check
        category "Architecture"
        severity :warning
        files "app/services/**/*.rb"
        requires :ast, :project
        description "Flags services calling more than 5 other services"

        MAX_DEPENDENCIES = 5

        def check(context)
          index = context.project_index
          services = index.classes.select { |c| c.file.include?("app/services") }
          service_names = services.map(&:name).to_set

          deps = Set.new
          return unless context.ast

          context.ast.each_node(:send) do |node|
            receiver = node.children[0]
            next unless receiver&.type == :const

            name = begin
              receiver.source
            rescue StandardError
              nil
            end
            deps << name if name && service_names.include?(name)
          end

          return if deps.size <= MAX_DEPENDENCIES

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "Service calls #{deps.size} other services (max #{MAX_DEPENDENCIES}): #{deps.to_a.join(", ")}")
        end
      end
    end
  end
end
