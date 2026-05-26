# frozen_string_literal: true

module Backpressure
  class Check
    class SkipSignal < StandardError; end

    attr_reader :violations, :skip_reason

    class << self
      def category(value = nil)
        if value
          @check_category = value
        else
          @check_category
        end
      end

      def check_category
        @check_category || (superclass.respond_to?(:check_category) ? superclass.check_category : nil)
      end

      def severity(value = nil)
        if value
          @check_severity = value
        else
          @check_severity
        end
      end

      def check_severity
        @check_severity || (superclass.respond_to?(:check_severity) ? superclass.check_severity : :warning)
      end

      def files(glob = nil)
        if glob
          @file_glob = glob
        else
          @file_glob
        end
      end

      def file_glob
        @file_glob || (superclass.respond_to?(:file_glob) ? superclass.file_glob : nil)
      end

      def requires(*contexts)
        if contexts.any?
          @required_contexts = contexts
        else
          @required_contexts
        end
      end

      def required_contexts
        @required_contexts || (superclass.respond_to?(:required_contexts) ? superclass.required_contexts : [:source])
      end

      def ratchet(mode = nil)
        if mode
          @ratchet_mode = mode
        else
          @ratchet_mode
        end
      end

      def ratchet_mode
        return @ratchet_mode if defined?(@ratchet_mode)
        superclass.respond_to?(:ratchet_mode) ? superclass.ratchet_mode : :strict
      end

      def compilable(value = true)
        @compilable = value
      end

      def compilable?
        @compilable || false
      end

      def check_name
        name&.split("::")&.last || "UnnamedCheck"
      end

      def matches_file?(path)
        return true unless file_glob
        File.fnmatch(file_glob, path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
      end
    end

    def initialize
      @violations = []
      @skipped = false
      @skip_reason = nil
    end

    def run(context)
      @context = context
      check(context)
    rescue SkipSignal
      # handled in skip()
    end

    def check(context)
      raise NotImplementedError, "#{self.class.name} must implement #check"
    end

    def skipped?
      @skipped
    end

    private

    def violation(node, message, auto_correctable: false, correction: nil)
      file = @context.file_path
      line, column = extract_location(node)

      @violations << Violation.new(
        check_name: self.class.check_name,
        category: self.class.check_category,
        severity: self.class.check_severity,
        message: message,
        file: file,
        line: line,
        column: column,
        auto_correctable: auto_correctable,
        correction: correction,
        source_node: node
      )
    end

    def skip(reason)
      @skipped = true
      @skip_reason = reason
      raise SkipSignal
    end

    def extract_location(node)
      if node.respond_to?(:loc) && node.loc.respond_to?(:line)
        [node.loc.line, node.loc.respond_to?(:column) ? node.loc.column : 0]
      elsif node.respond_to?(:line)
        [node.line, node.respond_to?(:column) ? node.column : 0]
      else
        [0, 0]
      end
    end
  end
end
