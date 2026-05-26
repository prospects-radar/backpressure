# frozen_string_literal: true

module Backpressure
  class Runner
    Result = Struct.new(:violations, :skipped, keyword_init: true) do
      def success?
        violations.none? { |v| v.severity == :error }
      end

      def violation_count
        violations.size
      end
    end

    def initialize(config:, registry:, project_index: nil)
      @config = config
      @registry = registry
      @project_index = project_index
    end

    def run(files:, only: nil)
      all_violations = []
      all_skipped = []

      build_project_index(files) if needs_project_index?(only)

      files.each do |file_path|
        checks = resolve_checks(file_path, only: only)
        source = File.read(file_path, encoding: "utf-8")
        next unless source.valid_encoding?

        checks.each do |check_class|
          context = build_context(check_class, source: source, file_path: file_path)
          instance = check_class.new
          instance.run(context)

          if instance.skipped?
            all_skipped << { check: check_class.check_name, file: file_path, reason: instance.skip_reason }
          else
            filtered = filter_skip_annotations(instance.violations, source)
            all_violations.concat(filtered)
          end
        end
      end

      Result.new(violations: all_violations.sort, skipped: all_skipped)
    end

    private

    def resolve_checks(file_path, only: nil)
      checks = @registry.for_file(file_path)
      checks = checks.select { |c| @config.check_enabled?(c.check_name) }
      checks = checks.select { |c| only.include?(c.check_name) } if only
      checks
    end

    def build_context(check_class, source:, file_path:)
      contexts = check_class.required_contexts
      ctx = if contexts.include?(:phlex)
              Contexts::PhlexContext.new(source: source, file_path: file_path)
            elsif contexts.include?(:ast)
              Contexts::AstContext.new(source: source, file_path: file_path)
            else
              Contexts::SourceContext.new(source: source, file_path: file_path)
            end
      ctx.instance_variable_set(:@project_index, @project_index) if contexts.include?(:project)
      ctx.define_singleton_method(:project_index) { @project_index } if contexts.include?(:project)
      ctx
    end

    def needs_project_index?(only)
      checks = only ? @registry.all.select { |c| only.include?(c.check_name) } : @registry.all
      checks.any? { |c| c.required_contexts.include?(:project) }
    end

    def build_project_index(files)
      return if @project_index

      @project_index = ProjectIndex.build(files)
    end

    def filter_skip_annotations(violations, source)
      lines = source.lines
      violations.reject do |v|
        line = lines[v.line - 1]
        next false unless line
        if line.match?(/backpressure:disable\s+(\S+)/)
          disabled = line.match(/backpressure:disable\s+(.+)/)[1].split(",").map(&:strip)
          disabled.include?(v.check_name) || disabled.include?("all")
        else
          false
        end
      end
    end
  end
end
