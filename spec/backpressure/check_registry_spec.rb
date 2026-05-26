# frozen_string_literal: true

RSpec.describe Backpressure::CheckRegistry do
  subject(:registry) { described_class.new }

  let(:check_a) do
    Class.new(Backpressure::Check) do
      category "Architecture"
      files "app/controllers/**/*.rb"
      def self.name; "CheckA"; end
      def check(context); end
    end
  end

  let(:check_b) do
    Class.new(Backpressure::Check) do
      category "AI/Prompts"
      files "app/ai/**/*.rb"
      def self.name; "CheckB"; end
      def check(context); end
    end
  end

  describe "#register" do
    it "adds a check class" do
      registry.register(check_a)
      expect(registry.all).to eq([check_a])
    end

    it "prevents duplicate registration" do
      registry.register(check_a)
      registry.register(check_a)
      expect(registry.all.size).to eq(1)
    end
  end

  describe "#for_file" do
    before do
      registry.register(check_a)
      registry.register(check_b)
    end

    it "returns checks matching a file path" do
      matches = registry.for_file("app/controllers/users_controller.rb")
      expect(matches).to eq([check_a])
    end

    it "returns empty for non-matching files" do
      matches = registry.for_file("db/migrate/001.rb")
      expect(matches).to be_empty
    end
  end

  describe "#by_name" do
    before { registry.register(check_a) }

    it "finds a check by name" do
      expect(registry.by_name("CheckA")).to eq(check_a)
    end

    it "returns nil for unknown name" do
      expect(registry.by_name("Unknown")).to be_nil
    end
  end

  describe "#by_category" do
    before do
      registry.register(check_a)
      registry.register(check_b)
    end

    it "filters by category" do
      expect(registry.by_category("Architecture")).to eq([check_a])
    end

    it "filters by category prefix" do
      expect(registry.by_category("AI")).to eq([check_b])
    end
  end

  describe "#load_from" do
    it "loads check files from a directory" do
      dir = Dir.mktmpdir
      File.write(File.join(dir, "sample_check.rb"), <<~RUBY)
        class SampleCheck < Backpressure::Check
          category "Test"
          def check(context); end
        end
      RUBY

      registry.load_from(dir)
      expect(registry.by_name("SampleCheck")).not_to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
