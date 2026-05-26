# frozen_string_literal: true

require "yaml"

module Backpressure
  class YamlLoader
    def self.load(path)
      data = YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
      build_check_class(data)
    end

    def self.load_all(directory)
      Dir.glob(File.join(directory, "**", "*.check.yml")).sort.map { |path| load(path) }
    end

    def self.build_check_class(data)
      klass = Class.new(AiCheck)

      klass_name = data["name"]
      klass.define_singleton_method(:name) { klass_name }
      klass.define_singleton_method(:check_name) { klass_name }

      klass.description(data["description"]) if data["description"]
      klass.category(data["category"]) if data["category"]
      klass.severity(data["severity"]&.to_sym) if data["severity"]
      klass.files(data["files"]) if data["files"]
      klass.requires(*Array(data["requires"]).map(&:to_sym)) if data["requires"]

      ai_data = data["ai"] || {}
      klass.ai_config(
        provider: ai_data["provider"]&.to_sym,
        model: ai_data["model"],
        temperature: ai_data["temperature"],
        max_tokens: ai_data["max_tokens"],
        timeout: ai_data["timeout"],
        strategy: ai_data["strategy"],
        schema: ai_data["schema"]
      )

      klass.prompt_template(data["prompt"]) if data["prompt"]

      klass
    end
  end
end
