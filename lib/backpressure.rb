# frozen_string_literal: true

require_relative "backpressure/version"

module Backpressure
  class Error < StandardError; end

  autoload :Check, "backpressure/check"
  autoload :Violation, "backpressure/violation"
  autoload :CheckRegistry, "backpressure/check_registry"
  autoload :Configuration, "backpressure/configuration"
  autoload :Runner, "backpressure/runner"
  autoload :Baseline, "backpressure/baseline"
  autoload :Ratchet, "backpressure/ratchet"
  autoload :Cache, "backpressure/cache"
  autoload :Correction, "backpressure/correction"
  autoload :AiCheck, "backpressure/ai_check"
  autoload :YamlLoader, "backpressure/yaml_loader"
  autoload :ProjectIndex, "backpressure/project_index"
  autoload :PluginDSL, "backpressure/plugin"
  autoload :CLI, "backpressure/cli"

  module Contexts
    autoload :AstContext, "backpressure/contexts/ast_context"
    autoload :SourceContext, "backpressure/contexts/source_context"
    autoload :GroupContext, "backpressure/contexts/group_context"
    autoload :ProjectContext, "backpressure/contexts/project_context"
  end

  module Corrections
    autoload :Replace, "backpressure/corrections/replace"
    autoload :Insert, "backpressure/corrections/insert"
    autoload :Remove, "backpressure/corrections/remove"
  end

  module Formatters
    autoload :Base, "backpressure/formatters/base"
    autoload :Pretty, "backpressure/formatters/pretty"
    autoload :Json, "backpressure/formatters/json"
  end

  module AI
    autoload :Provider, "backpressure/ai/provider"
    autoload :Strategy, "backpressure/ai/strategy"

    module Strategies
      autoload :PreFilter, "backpressure/ai/strategies/pre_filter"
      autoload :Consensus, "backpressure/ai/strategies/consensus"
    end

    module Providers
    end
  end

  module Compiler
    autoload :RubocopCompiler, "backpressure/compiler/rubocop_compiler"
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def registry
      @registry ||= CheckRegistry.new
    end

    def formatter_registry
      @formatter_registry ||= {}
    end

    def context_registry
      @context_registry ||= {}
    end

    def register_plugin(name, &block)
      PluginDSL.new(name, &block)
    end

    def reset!
      @configuration = nil
      @registry = nil
      @formatter_registry = nil
      @context_registry = nil
    end
  end
end
