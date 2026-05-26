# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module HumanOversight
        class UserFacingWithoutReview < Check
          category "AI/HumanOversight"
          severity :warning
          files "app/{controllers,views}/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/agent.*result|\.run\b.*response/)
            return if context.source.match?(/moderate|review|filter|sanitize/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent output displayed to end user without moderation/review")
          end
        end
      end
    end
  end
end
