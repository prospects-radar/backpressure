# frozen_string_literal: true

module Backpressure
  module AI
    class Provider
      attr_reader :config

      def initialize(config:)
        @config = config
      end

      def complete(prompt:, model:, temperature:, max_tokens:, schema:)
        raise NotImplementedError
      end

      class << self
        def providers
          @providers ||= {}
        end

        def register(name, klass)
          providers[name.to_sym] = klass
        end

        def for(name, config:)
          klass = providers[name.to_sym]
          raise Backpressure::Error, "Unknown provider: #{name}" unless klass
          klass.new(config: config)
        end
      end
    end
  end
end

module Backpressure
  module AI
    module Providers
      class Test < Provider
        def complete(prompt:, model:, temperature:, max_tokens:, schema:)
          []
        end
      end
    end
  end
end

Backpressure::AI::Provider.register(:test, Backpressure::AI::Providers::Test)
