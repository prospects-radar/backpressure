# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::Cache do
  let(:cache_dir) { Dir.mktmpdir("bp_cache") }
  subject(:cache) { described_class.new(dir: cache_dir) }

  after { FileUtils.remove_entry(cache_dir) if Dir.exist?(cache_dir) }

  describe "#fetch" do
    it "returns nil on cache miss" do
      result = cache.fetch(check_name: "CheckA", file_path: "a.rb", file_content: "code", check_version: "v1")
      expect(result).to be_nil
    end

    it "stores and retrieves results" do
      violations = [{ "check_name" => "CheckA", "message" => "bad", "line" => 10 }]

      cache.store(
        check_name: "CheckA", file_path: "a.rb",
        file_content: "code", check_version: "v1",
        result: violations
      )

      fetched = cache.fetch(check_name: "CheckA", file_path: "a.rb", file_content: "code", check_version: "v1")
      expect(fetched).to eq(violations)
    end

    it "misses when file content changes" do
      cache.store(
        check_name: "CheckA", file_path: "a.rb",
        file_content: "old code", check_version: "v1",
        result: []
      )

      fetched = cache.fetch(check_name: "CheckA", file_path: "a.rb", file_content: "new code", check_version: "v1")
      expect(fetched).to be_nil
    end

    it "misses when check version changes" do
      cache.store(
        check_name: "CheckA", file_path: "a.rb",
        file_content: "code", check_version: "v1",
        result: []
      )

      fetched = cache.fetch(check_name: "CheckA", file_path: "a.rb", file_content: "code", check_version: "v2")
      expect(fetched).to be_nil
    end
  end

  describe "#clear" do
    it "removes all cached data" do
      cache.store(check_name: "A", file_path: "a.rb", file_content: "c", check_version: "v", result: [])
      cache.clear
      expect(cache.fetch(check_name: "A", file_path: "a.rb", file_content: "c", check_version: "v")).to be_nil
    end
  end

  describe "#stats" do
    it "reports cache size" do
      cache.store(check_name: "A", file_path: "a.rb", file_content: "c", check_version: "v", result: [])
      cache.store(check_name: "B", file_path: "b.rb", file_content: "c", check_version: "v", result: [])
      expect(cache.stats[:entries]).to eq(2)
    end
  end
end
