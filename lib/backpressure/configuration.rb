# frozen_string_literal: true

require "yaml"

module Backpressure
  class Configuration
    attr_reader :check_paths, :include_patterns, :exclude_patterns,
                :ai_config, :cache_enabled, :cache_dir,
                :baseline_file, :anti_tamper, :format, :plugins

    def initialize
      @check_paths = ["checks/"]
      @include_patterns = ["**/*.rb"]
      @exclude_patterns = []
      @ai_config = {}
      @cache_enabled = true
      @cache_dir = ".backpressure_cache"
      @baseline_file = "backpressure_baseline.yml"
      @anti_tamper = true
      @format = :pretty
      @plugins = []
      @check_overrides = {}
    end

    def self.from_file(path)
      data = YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
      from_hash(data)
    end

    def self.from_hash(data)
      config = new
      config.apply(data)
      config
    end

    def apply(data)
      @check_paths = data["check_paths"] if data["check_paths"]
      @include_patterns = data["include"] if data["include"]
      @exclude_patterns = data["exclude"] if data["exclude"]
      @format = data["format"]&.to_sym if data["format"]
      @ai_config = data["ai"] if data["ai"]
      @plugins = data["plugins"] || []

      if data["cache"]
        @cache_enabled = data["cache"].fetch("enabled", @cache_enabled)
        @cache_dir = data["cache"].fetch("dir", @cache_dir)
      end

      if data["ratchet"]
        @baseline_file = data["ratchet"].fetch("baseline_file", @baseline_file)
        @anti_tamper = data["ratchet"].fetch("anti_tamper", @anti_tamper)
      end

      @check_overrides = data["checks"] || {}
    end

    def check_overrides(name)
      @check_overrides[name] || {}
    end

    def check_enabled?(name)
      overrides = check_overrides(name)
      overrides.fetch("enabled", true)
    end

    def resolve_tier(tier_name)
      tiers = ai_config.dig("tiers") || {}
      tiers[tier_name.to_s] || tier_name.to_s
    end

    def ai_provider
      ai_config["default_provider"]
    end
  end
end
