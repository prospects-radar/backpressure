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
        File.read(file_path)
      end
    end
  end
end
