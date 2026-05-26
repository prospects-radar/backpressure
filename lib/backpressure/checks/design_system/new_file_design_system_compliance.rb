# frozen_string_literal: true

require_relative "raw_html_ratchet"

module Backpressure
  module Checks
    module DesignSystem
      class NewFileDesignSystemCompliance < Check
        category "DesignSystem"
        severity :error
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :source
        ratchet false

        RAW_ELEMENTS = RawHTMLRatchet::RAW_ELEMENTS
        PATTERN = RawHTMLRatchet::PATTERN

        def check(context)
          raw_count = context.lines.count { |line| line.match?(PATTERN) }
          return if raw_count.zero?

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "New GlassMorph file contains #{raw_count} raw HTML element(s) — must use design system components only")
        end
      end
    end
  end
end
