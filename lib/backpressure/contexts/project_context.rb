# frozen_string_literal: true

module Backpressure
  module Contexts
    class ProjectContext
      attr_reader :project, :file_path

      def initialize(project:, file_path:)
        @project = project
        @file_path = file_path
      end

      def source
        @source ||= File.read(file_path)
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
    end
  end
end
