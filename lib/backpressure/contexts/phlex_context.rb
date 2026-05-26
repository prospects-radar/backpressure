# frozen_string_literal: true

module Backpressure
  module Contexts
    class PhlexContext
      attr_reader :source, :file_path, :tree, :parser

      def initialize(source:, file_path:)
        @source = source
        @file_path = file_path
        @parser = Backpressure::Phlex::Parser.new(source, file_path)
        @tree = @parser.parse
      end

      def lines
        @lines ||= source.split("\n", -1)
      end

      def line_count
        lines.reject(&:empty?).size
      end

      def line(number)
        lines[number - 1]
      end

      def raw_html_elements
        Backpressure::Phlex::Parser::RAW_HTML_ELEMENTS
      end

      def self.from_file(path)
        new(source: File.read(path), file_path: path)
      end
    end
  end
end
