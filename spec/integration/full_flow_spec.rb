# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Full backpressure flow" do
  let(:project) { Dir.mktmpdir("bp_full") }

  after { FileUtils.remove_entry(project) }

  it "runs checks, ratchets, caches, and reports violations end-to-end" do
    checks_dir = File.join(project, "checks")
    FileUtils.mkdir_p(checks_dir)

    File.write(File.join(checks_dir, "no_puts_full.rb"), <<~RUBY)
      class NoPutsFull < Backpressure::Check
        category "Style"
        severity :warning
        files "**/*.rb"
        requires :ast

        def check(context)
          context.ast.each_node(:send) do |node|
            if node.method_name == :puts
              violation(node, "Avoid puts in production code")
            end
          end
        end
      end
    RUBY

    target = File.join(project, "app.rb")
    File.write(target, "class App\n  def run\n    puts 'hello'\n  end\nend\n")

    registry = Backpressure::CheckRegistry.new
    registry.load_from(checks_dir)

    config = Backpressure::Configuration.new
    runner = Backpressure::Runner.new(config: config, registry: registry)

    result = runner.run(files: [target])
    expect(result.violations.size).to eq(1)

    baseline_path = File.join(project, "baseline.yml")
    ratchet = Backpressure::Ratchet.new(baseline_path: baseline_path, anti_tamper: true)
    ratchet.update_baseline(result.violations)

    ratchet_result = ratchet.evaluate(result.violations)
    expect(ratchet_result.pass?).to be true

    File.write(target, "class App\n  def run\n    puts 'hello'\n    puts 'world'\n  end\nend\n")
    result2 = runner.run(files: [target])
    expect(result2.violations.size).to eq(2)

    ratchet_result2 = ratchet.evaluate(result2.violations)
    expect(ratchet_result2.pass?).to be false
    expect(ratchet_result2.new_violations.size).to eq(1)

    cache = Backpressure::Cache.new(dir: File.join(project, ".cache"))
    cache.store(
      check_name: "NoPutsFull", file_path: target,
      file_content: File.read(target), check_version: "v1",
      result: [{ line: 3, message: "Avoid puts" }]
    )
    cached = cache.fetch(
      check_name: "NoPutsFull", file_path: target,
      file_content: File.read(target), check_version: "v1"
    )
    expect(cached).not_to be_nil

    json = Backpressure::Formatters::Json.new.format(result2.violations)
    parsed = JSON.parse(json)
    expect(parsed.size).to eq(2)
  end
end
