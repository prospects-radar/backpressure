# frozen_string_literal: true

module Backpressure
  class PluginDSL
    def initialize(name, &block)
      @name = name
      instance_eval(&block)
    end

    def checks_from(directory)
      Backpressure.registry.load_from(directory)
    end

    def formatter(name, klass)
      Backpressure.formatter_registry[name.to_sym] = klass
    end

    def context(name, &block)
      Backpressure.context_registry[name.to_sym] = block
    end
  end
end
