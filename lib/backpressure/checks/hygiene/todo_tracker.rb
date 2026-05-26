# frozen_string_literal: true

module Backpressure
  module Checks
    module Hygiene
      class TodoTracker < Check
        category "Hygiene"
        severity :warning
        files "**/*.rb"
        requires :source
        ratchet :strict
        description "Tracks TODO, FIXME, and HACK comments for ratcheted removal"

        PATTERN = /\b(TODO|FIXME|HACK)\b/i

        def check(context)
          context.lines.each_with_index do |line, idx|
            next unless line.match?(PATTERN)

            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            match = line.match(PATTERN)
            violation(node, "#{match[1].upcase} comment found — tracked by ratchet")
          end
        end
      end
    end
  end
end
