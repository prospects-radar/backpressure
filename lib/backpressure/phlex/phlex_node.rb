# frozen_string_literal: true

module Backpressure
  module Phlex
    class PhlexNode
      attr_reader :name, :kwargs, :children, :parent, :source_node

      def initialize(name:, kwargs: {}, children: [], parent: nil, source_node: nil)
        @name = name
        @kwargs = kwargs
        @children = children
        @parent = parent
        @source_node = source_node
      end

      def kwarg(key)
        @kwargs[key]
      end

      def each_node(component_name = nil, &block)
        return enum_for(:each_node, component_name) unless block_given?

        unless @name == :__root__
          yield self if component_name.nil? || @name == component_name
        end

        @children.each { |child| child.each_node(component_name, &block) }
      end

      def direct_children_named(component_name)
        @children.select { |c| c.name == component_name }
      end

      def ancestor?(component_name)
        return false if @parent.nil? || @parent.name == :__root__
        return true if @parent.name == component_name

        @parent.ancestor?(component_name)
      end

      def any_ancestor?(&block)
        parent = @parent
        while parent && parent.name != :__root__
          return true if yield(parent)

          parent = parent.parent
        end
        false
      end

      def root
        @parent.nil? ? self : @parent.root
      end

      def inspect
        args = @kwargs.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        children_str = @children.empty? ? "" : " [#{@children.map(&:name).join(', ')}]"
        "#{@name}(#{args})#{children_str}"
      end

      alias to_s inspect
    end
  end
end
