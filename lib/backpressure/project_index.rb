# frozen_string_literal: true

require "rubocop-ast"

module Backpressure
  class ProjectIndex
    ClassEntry = Struct.new(:name, :file, :node, :superclass_name, keyword_init: true)

    attr_reader :classes, :files

    def initialize(classes:, files:, const_refs: nil, file_sources: nil)
      @classes = classes
      @files = files
      @const_refs = const_refs
      @file_sources = file_sources
    end

    def self.build(file_paths)
      all_classes = []
      const_refs = Hash.new { |h, k| h[k] = [] }
      file_sources = {}

      file_paths.each do |path|
        source = File.read(path, encoding: "utf-8")
        next unless source.valid_encoding?

        file_sources[path] = source

        processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
        next unless processed.ast

        processed.ast.each_node(:class) do |node|
          name = node.children[0]&.source
          superclass = node.children[1]&.source
          all_classes << ClassEntry.new(
            name: name,
            file: path,
            node: node,
            superclass_name: superclass
          )
        end

        processed.ast.each_node(:const) do |node|
          const_refs[node.source] << path
        end
      end

      const_refs.each_value(&:uniq!)
      new(classes: all_classes, files: file_paths, const_refs: const_refs, file_sources: file_sources)
    end

    def source_for(path)
      if @file_sources
        @file_sources[path]
      elsif File.exist?(path)
        source = File.read(path, encoding: "utf-8")
        source.valid_encoding? ? source : nil
      end
    end

    def classes_in(glob)
      classes.select { |c| File.fnmatch(glob, c.file, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
    end

    def classes_matching(pattern)
      classes.select { |c| c.name.match?(pattern) }
    end

    def references_to(target_classes)
      if @const_refs
        refs = []
        target_classes.each do |target|
          (@const_refs[target.name] || []).each do |path|
            refs << OpenStruct.new(file: path, node: nil, target: target)
          end
        end
        return refs
      end

      target_names = target_classes.map(&:name)
      refs = []
      files.each do |path|
        next unless File.exist?(path)
        source = File.read(path, encoding: "utf-8")
        next unless source.valid_encoding?
        processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
        next unless processed.ast

        processed.ast.each_node(:const) do |node|
          const_name = node.source
          if target_names.include?(const_name)
            target = target_classes.find { |c| c.name == const_name }
            refs << OpenStruct.new(file: path, node: node, target: target)
          end
        end
      end
      refs
    end
  end
end
