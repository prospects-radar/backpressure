# frozen_string_literal: true

module Backpressure
  module Formatters
    class Pretty < Base
      SEVERITY_COLORS = {
        error: "\e[31m",
        warning: "\e[33m",
        info: "\e[36m"
      }.freeze
      RESET = "\e[0m"

      def format(violations)
        return "No violations found.\n" if violations.empty?

        lines = violations.sort.map { |v| format_violation(v) }
        auto_count = violations.count(&:auto_correctable)

        summary = "\nbackpressure: #{violations.size} violation(s) found."
        summary += "\n  #{auto_count} auto-correctable (use backpressure fix)" if auto_count > 0
        manual = violations.size - auto_count
        summary += "\n  #{manual} require manual fixes" if manual > 0

        (lines + [summary, ""]).join("\n")
      end

      private

      def format_violation(v)
        color = SEVERITY_COLORS.fetch(v.severity, "")
        parts = ["#{v.location}: #{color}[#{v.check_name}]#{RESET} #{v.message}"]
        parts << "  auto-correctable" if v.auto_correctable
        parts.join("\n")
      end
    end
  end
end
