# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::Compiler::RubocopCompiler do
  let(:tmpdir) { Dir.mktmpdir("bp_compile") }

  after { FileUtils.remove_entry(tmpdir) }

  let(:compilable_check) do
    Class.new(Backpressure::Check) do
      requires :ast
      compilable
      category "Architecture"

      def self.name; "NoDirectAR"; end

      def check(context)
        context.ast.each_node(:send) do |node|
          if node.method_name == :where
            violation(node, "Use a service object")
          end
        end
      end
    end
  end

  let(:non_compilable_check) do
    Class.new(Backpressure::Check) do
      requires :ast, :project
      category "Architecture"
      def self.name; "CrossFileCheck"; end
      def check(context); end
    end
  end

  describe "#compilable?" do
    it "returns true for ast-only compilable checks" do
      expect(described_class.compilable?(compilable_check)).to be true
    end

    it "returns false for checks with project dependency" do
      expect(described_class.compilable?(non_compilable_check)).to be false
    end
  end

  describe "#compile" do
    it "generates a RuboCop cop file" do
      output_dir = File.join(tmpdir, "lib/rubocop/cop/backpressure")
      described_class.new(output_dir: output_dir).compile(compilable_check)

      cop_path = File.join(output_dir, "no_direct_ar.rb")
      expect(File.exist?(cop_path)).to be true

      content = File.read(cop_path)
      expect(content).to include("module RuboCop")
      expect(content).to include("class NoDirectAR")
      expect(content).to include("Backpressure/NoDirectAR")
    end
  end
end
