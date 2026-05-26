# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"

module Backpressure
  class Cache
    def initialize(dir:)
      @dir = dir
    end

    def fetch(check_name:, file_path:, file_content:, check_version:)
      path = cache_path(check_name, file_path, file_content, check_version)
      return nil unless File.exist?(path)

      JSON.parse(File.read(path))
    end

    def store(check_name:, file_path:, file_content:, check_version:, result:)
      path = cache_path(check_name, file_path, file_content, check_version)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.generate(result))
    end

    def clear
      FileUtils.rm_rf(@dir)
    end

    def stats
      entries = Dir.glob(File.join(@dir, "**", "*.json")).size
      total_bytes = Dir.glob(File.join(@dir, "**", "*.json")).sum { |f| File.size(f) }
      { entries: entries, total_bytes: total_bytes }
    end

    private

    def cache_path(check_name, file_path, file_content, check_version)
      key = Digest::SHA256.hexdigest("#{check_version}:#{file_path}:#{file_content}")
      File.join(@dir, check_name, "#{key}.json")
    end
  end
end
