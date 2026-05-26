# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe "End-to-end check flow" do
  let(:project_dir) { Dir.mktmpdir("bp_test") }

  after { FileUtils.remove_entry(project_dir) }

  it "runs an AST check against a file and reports violations" do
    checks_dir = File.join(project_dir, "checks")
    FileUtils.mkdir_p(checks_dir)

    File.write(File.join(checks_dir, "no_puts.rb"), <<~RUBY)
      class NoPuts < Backpressure::Check
        category "Style"
        severity :warning
        files "**/*.rb"
        requires :ast

        def check(context)
          context.ast.each_node(:send) do |node|
            if node.method_name == :puts
              violation(node, "Avoid using puts in production code")
            end
          end
        end
      end
    RUBY

    target = File.join(project_dir, "app.rb")
    File.write(target, <<~RUBY)
      class App
        def run
          puts "hello"
          do_work
          puts "done"
        end
      end
    RUBY

    registry = Backpressure::CheckRegistry.new
    registry.load_from(checks_dir)

    config = Backpressure::Configuration.new
    runner = Backpressure::Runner.new(config: config, registry: registry)
    result = runner.run(files: [target])

    expect(result.violations.size).to eq(2)
    expect(result.violations.map(&:message)).to all(eq("Avoid using puts in production code"))
    expect(result.violations.map(&:line)).to contain_exactly(3, 5)

    pretty = Backpressure::Formatters::Pretty.new.format(result.violations)
    expect(pretty).to include("NoPuts")
    expect(pretty).to include("2 violation(s)")

    json_output = Backpressure::Formatters::Json.new.format(result.violations)
    parsed = JSON.parse(json_output)
    expect(parsed.size).to eq(2)
  end

  it "runs a source check against a file" do
    checks_dir = File.join(project_dir, "checks")
    FileUtils.mkdir_p(checks_dir)

    File.write(File.join(checks_dir, "no_todo.rb"), <<~RUBY)
      class NoTodo < Backpressure::Check
        category "Style"
        files "**/*.rb"
        requires :source

        def check(context)
          context.lines.each_with_index do |line, idx|
            if line.match?(/TODO/i)
              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Remove TODO comment")
            end
          end
        end
      end
    RUBY

    target = File.join(project_dir, "app.rb")
    File.write(target, "# TODO: fix this\ncode\n# TODO: and this\n")

    registry = Backpressure::CheckRegistry.new
    registry.load_from(checks_dir)

    config = Backpressure::Configuration.new
    runner = Backpressure::Runner.new(config: config, registry: registry)
    result = runner.run(files: [target])

    expect(result.violations.size).to eq(2)
    expect(result.violations.map(&:line)).to contain_exactly(1, 3)
  end
end
