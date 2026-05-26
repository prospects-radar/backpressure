# frozen_string_literal: true

require "ostruct"

RSpec.describe Backpressure::Check do
  let(:test_check_class) do
    Class.new(described_class) do
      category "Architecture"
      severity :error
      files "app/controllers/**/*.rb"
      requires :ast

      def self.name
        "NoDirectAR"
      end

      def check(context)
        violation(context.source_node_stub, "Found direct AR")
      end
    end
  end

  describe "class-level DSL" do
    it "sets category" do
      expect(test_check_class.check_category).to eq("Architecture")
    end

    it "sets severity" do
      expect(test_check_class.check_severity).to eq(:error)
    end

    it "sets file glob" do
      expect(test_check_class.file_glob).to eq("app/controllers/**/*.rb")
    end

    it "sets required contexts" do
      expect(test_check_class.required_contexts).to eq([:ast])
    end

    it "defaults severity to :warning" do
      klass = Class.new(described_class) { def self.name; "DefaultCheck"; end }
      expect(klass.check_severity).to eq(:warning)
    end

    it "defaults ratchet to :strict" do
      expect(test_check_class.ratchet_mode).to eq(:strict)
    end

    it "supports multiple requires" do
      klass = Class.new(described_class) do
        requires :ast, :project
        def self.name; "Multi"; end
      end
      expect(klass.required_contexts).to eq([:ast, :project])
    end
  end

  describe "instance behavior" do
    it "collects violations" do
      node_stub = OpenStruct.new(loc: OpenStruct.new(line: 10, column: 5))
      context_stub = OpenStruct.new(file_path: "app/controllers/foo.rb", source_node_stub: node_stub)

      check = test_check_class.new
      check.run(context_stub)

      expect(check.violations.size).to eq(1)
      v = check.violations.first
      expect(v.message).to eq("Found direct AR")
      expect(v.check_name).to eq("NoDirectAR")
      expect(v.severity).to eq(:error)
      expect(v.file).to eq("app/controllers/foo.rb")
      expect(v.line).to eq(10)
    end

    it "supports skip" do
      skip_check_class = Class.new(described_class) do
        def self.name; "SkipCheck"; end
        def check(context)
          skip("Not applicable")
        end
      end

      check = skip_check_class.new
      context_stub = OpenStruct.new(file_path: "foo.rb")
      check.run(context_stub)

      expect(check.violations).to be_empty
      expect(check.skipped?).to be true
      expect(check.skip_reason).to eq("Not applicable")
    end
  end

  describe ".check_name" do
    it "returns the class name without module prefix" do
      expect(test_check_class.check_name).to eq("NoDirectAR")
    end
  end

  describe ".matches_file?" do
    it "returns true for files matching the glob" do
      expect(test_check_class.matches_file?("app/controllers/users_controller.rb")).to be true
    end

    it "returns false for non-matching files" do
      expect(test_check_class.matches_file?("app/models/user.rb")).to be false
    end

    it "matches all files when no glob is set" do
      klass = Class.new(described_class) { def self.name; "AllFiles"; end }
      expect(klass.matches_file?("anything.rb")).to be true
    end
  end
end
