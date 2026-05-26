# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Testing
        class AgentWithoutSpec < Check
          category "AI/Testing"
          severity :warning
          files "app/ai/agents/**/*.rb"
          requires :source, :project
          description "Flags RAAF agent classes with no corresponding spec file"

          def check(context)
            agent_file = context.file_path
            spec_file = agent_file.sub("app/ai/agents/", "spec/ai/agents/").sub(".rb", "_spec.rb")

            unless context.project_index.files.include?(spec_file) || File.exist?(spec_file)
              node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
              violation(node, "Agent has no corresponding spec file at #{spec_file}")
            end
          end
        end
      end
    end
  end
end
