# frozen_string_literal: true

module Backpressure
  module Checks
    module Architecture
      class CircularServiceDependency < Check
        category "Architecture"
        severity :error
        files "app/services/**/*.rb"
        requires :ast, :project

        def check(context)
          index = context.project_index
          services = index.classes.select { |c| c.file.include?("app/services") }
          service_names = services.map(&:name).to_set

          this_class = services.find { |c| c.file == context.file_path }
          return unless this_class

          deps = find_service_deps(context.ast, service_names)
          deps.each do |dep_name|
            dep_entry = services.find { |c| c.name == dep_name }
            next unless dep_entry

            reverse_deps = find_service_deps_in_file(dep_entry.file, service_names)
            next unless reverse_deps.include?(this_class.name)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Circular dependency: #{this_class.name} <-> #{dep_name}")
          end
        end

        private

        def find_service_deps(ast, service_names)
          deps = Set.new
          return deps unless ast

          ast.each_node(:send) do |node|
            receiver = node.children[0]
            next unless receiver&.type == :const

            name = begin
              receiver.source
            rescue StandardError
              nil
            end
            deps << name if name && service_names.include?(name)
          end
          deps
        end

        def find_service_deps_in_file(file_path, service_names)
          return Set.new unless File.exist?(file_path)

          source = File.read(file_path)
          processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
          return Set.new unless processed.ast

          find_service_deps(processed.ast, service_names)
        end
      end
    end
  end
end
