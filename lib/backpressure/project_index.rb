# frozen_string_literal: true

require "rubocop-ast"

module Backpressure
  class ProjectIndex
    ClassEntry = Struct.new(:name, :file, :node, :superclass_name, keyword_init: true)

    attr_reader :classes, :files

    def initialize(classes:, files:)
      @classes = classes
      @files = files
    end

    def self.build(file_paths)
      all_classes = []
      file_paths.each do |path|
        source = File.read(path)
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
      end

      new(classes: all_classes, files: file_paths)
    end

    def classes_in(glob)
      classes.select { |c| File.fnmatch(glob, c.file, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
    end

    def classes_matching(pattern)
      classes.select { |c| c.name.match?(pattern) }
    end

    def references_to(target_classes)
      target_names = target_classes.map(&:name)
      refs = []

      files.each do |path|
        source = File.read(path)
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
