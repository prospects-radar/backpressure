# frozen_string_literal: true

module Backpressure
  module AI
    module Strategies
      class Consensus
        def initialize(count:)
          @count = count
        end

        def evaluate(&block)
          all_results = @count.times.map { |i| block.call(i) }

          vote_counts = Hash.new(0)
          all_results.flatten.each do |violation|
            key = violation.values_at("line", "message").join(":")
            vote_counts[key] += 1
          end

          threshold = (@count / 2.0).ceil

          all_violations = all_results.flatten.uniq { |v| v.values_at("line", "message").join(":") }
          all_violations.map do |v|
            key = v.values_at("line", "message").join(":")
            v.merge(agreed: vote_counts[key] >= threshold, votes: vote_counts[key])
          end
        end
      end
    end
  end
end
