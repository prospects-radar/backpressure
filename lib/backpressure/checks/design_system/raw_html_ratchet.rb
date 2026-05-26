# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class RawHTMLRatchet < Check
        category "DesignSystem"
        severity :error
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :source
        ratchet :strict
        description "Ratchets raw HTML elements in GlassMorph Phlex views"

        RAW_ELEMENTS = %w[
          div span p a button input textarea select label
          h1 h2 h3 h4 h5 h6 small hr svg img i ul ol li
          table thead tbody tr td th form fieldset
        ].freeze

        PATTERN = /^\s+(#{RAW_ELEMENTS.join('|')})\s*[\(\s{]/

        def check(context)
          context.lines.each_with_index do |line, idx|
            next unless line.match?(PATTERN)

            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            violation(node, "Raw HTML element in GlassMorph file")
          end
        end
      end
    end
  end
end
