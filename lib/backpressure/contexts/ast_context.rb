# frozen_string_literal: true

require "rubocop-ast"

module Backpressure
  module Contexts
    class AstContext
      attr_reader :source, :file_path

      def initialize(source:, file_path:)
        @source = source
        @file_path = file_path
      end

      def ast
        @ast ||= processed_source.ast
      end

      def processed_source
        @processed_source ||= RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
      end

      def self.from_file(path)
        new(source: File.read(path), file_path: path)
      end
    end
  end
end
