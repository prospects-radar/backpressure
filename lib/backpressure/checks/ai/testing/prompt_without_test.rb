# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Testing
        class PromptWithoutTest < Check
          category "AI/Testing"
          severity :warning
          files "app/ai/prompts/**/*.rb"
          requires :source, :project

          def check(context)
            prompt_file = context.file_path
            spec_file = prompt_file.sub("app/ai/prompts/", "spec/ai/prompts/").sub(".rb", "_spec.rb")

            unless context.project_index.files.include?(spec_file) || File.exist?(spec_file)
              node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
              violation(node, "Prompt class has no spec at #{spec_file}")
            end
          end
        end
      end
    end
  end
end
