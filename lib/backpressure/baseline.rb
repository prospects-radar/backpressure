# frozen_string_literal: true

require "yaml"

module Backpressure
  class Baseline
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def self.write(violations, path:)
      checks = violations.group_by(&:check_name).transform_values do |vs|
        {
          "count" => vs.size,
          "files" => vs.sort.map(&:identity).map { |id| id.split(":", 2).last }
        }
      end

      content = {
        "generated_at" => Time.now.utc.iso8601,
        "checks" => checks
      }

      File.write(path, content.to_yaml)
    end

    def self.load(path)
      if File.exist?(path)
        data = YAML.safe_load_file(path) || {}
        new(data)
      else
        new({})
      end
    end

    def empty?
      checks.empty?
    end

    def count_for(check_name)
      checks.dig(check_name, "count") || 0
    end

    def files_for(check_name)
      checks.dig(check_name, "files") || []
    end

    def new_violations(current_violations)
      return current_violations if empty?

      current_violations.reject do |v|
        identity_suffix = v.identity.split(":", 2).last
        files_for(v.check_name).include?(identity_suffix)
      end
    end

    def tampered?(current_violations)
      return false if empty?

      current_by_check = current_violations.group_by(&:check_name)

      checks.any? do |check_name, baseline_data|
        actual = current_by_check.fetch(check_name, []).size
        baseline_data["count"] > actual
      end
    end

    private

    def checks
      @data.fetch("checks", {})
    end
  end
end
