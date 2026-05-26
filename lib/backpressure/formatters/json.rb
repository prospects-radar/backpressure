# frozen_string_literal: true

require "json"

module Backpressure
  module Formatters
    class Json < Base
      def format(violations)
        JSON.pretty_generate(violations.sort.map { |v| serialize(v) })
      end

      private

      def serialize(v)
        {
          check_name: v.check_name,
          category: v.category,
          severity: v.severity.to_s,
          message: v.message,
          file: v.file,
          line: v.line,
          column: v.column,
          auto_correctable: v.auto_correctable
        }
      end
    end
  end
end
