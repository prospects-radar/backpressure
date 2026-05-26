# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Skip annotations" do
  let(:tmpdir) { Dir.mktmpdir("bp_skip") }

  after { FileUtils.remove_entry(tmpdir) }

  let(:check_class) do
    Class.new(Backpressure::Check) do
      files "**/*.rb"
      requires :source
      def self.name; "NoPuts"; end
      def check(context)
        context.lines.each_with_index do |line, idx|
          if line.match?(/\bputs\b/) && !line.match?(/backpressure:disable/)
            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            violation(node, "No puts")
          end
        end
      end
    end
  end

  it "filters violations on lines with backpressure:disable" do
    target = File.join(tmpdir, "test.rb")
    File.write(target, <<~RUBY)
      puts "this should fail"
      puts "this is ok" # backpressure:disable NoPuts
      puts "also fails"
    RUBY

    registry = Backpressure::CheckRegistry.new
    registry.register(check_class)
    config = Backpressure::Configuration.new
    runner = Backpressure::Runner.new(config: config, registry: registry)
    result = runner.run(files: [target])

    expect(result.violations.size).to eq(2)
    expect(result.violations.map(&:line)).to contain_exactly(1, 3)
  end
end
