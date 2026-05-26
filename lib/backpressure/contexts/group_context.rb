# frozen_string_literal: true

module Backpressure
  module Contexts
    class GroupContext
      attr_reader :file_path, :group

      def initialize(roles:, primary_role:)
        @file_path = roles[primary_role]
        @group = build_group(roles)
      end

      def source
        primary_context&.source
      end

      private

      def build_group(roles)
        roles.transform_values do |path|
          if File.exist?(path)
            SourceContext.from_file(path)
          end
        end
      end

      def primary_context
        @group.values.compact.first
      end
    end
  end
end
