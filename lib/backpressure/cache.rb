# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"

module Backpressure
  class Cache
    def initialize(dir:, enabled: true)
      @dir = dir
      @enabled = enabled
    end

    def enabled?
      @enabled
    end

    def fetch(check_name:, file_path:, file_content:, check_version:)
      return nil unless @enabled
      path = cache_path(check_name, file_path, file_content, check_version)
      return nil unless File.exist?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError
      nil
    end

    def store(check_name:, file_path:, file_content:, check_version:, result:)
      return unless @enabled
      path = cache_path(check_name, file_path, file_content, check_version)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.generate(result))
    end

    def clear
      FileUtils.rm_rf(@dir)
    end

    def stats
      files = Dir.glob(File.join(@dir, "**", "*.json"))
      total_bytes = files.sum { |f| File.size(f) }
      { enabled: @enabled, entries: files.size, total_bytes: total_bytes, dir: @dir }
    end

    def show
      checks_dir = @dir
      return [] unless Dir.exist?(checks_dir)
      Dir.glob(File.join(checks_dir, "*")).filter_map do |check_dir|
        next unless File.directory?(check_dir)
        check_name = File.basename(check_dir)
        entries = Dir.glob(File.join(check_dir, "*.json")).size
        { check: check_name, entries: entries }
      end.sort_by { |e| e[:check] }
    end

    private

    def cache_path(check_name, file_path, file_content, check_version)
      key = Digest::SHA256.hexdigest("#{check_version}:#{file_path}:#{file_content}")
      File.join(@dir, check_name, "#{key}.json")
    end
  end
end
