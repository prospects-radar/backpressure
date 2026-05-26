# frozen_string_literal: true

module Backpressure
  class Violation
    attr_reader :check_name, :category, :severity, :message,
                :file, :line, :column, :auto_correctable, :correction, :source_node

    def initialize(check_name:, message:, file:, line:, column: 0, category: nil,
                   severity: :warning, auto_correctable: false, correction: nil, source_node: nil)
      @check_name = check_name
      @category = category
      @severity = severity
      @message = message
      @file = file
      @line = line
      @column = column
      @auto_correctable = auto_correctable
      @correction = correction
      @source_node = source_node
    end

    def location
      "#{file}:#{line}:#{column}"
    end

    def identity
      "#{check_name}:#{file}:#{line}"
    end

    def <=>(other)
      [file, line, column] <=> [other.file, other.line, other.column]
    end
  end
end
