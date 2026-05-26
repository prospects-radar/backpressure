# frozen_string_literal: true

require "backpressure/checks/ai/output_safety/unvalidated_output"

RSpec.describe Backpressure::Checks::AI::OutputSafety::UnvalidatedOutput do
  def run_check(source, file_path: "app/services/test.rb")
    context = Backpressure::Contexts::AstContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags .run without validation" do
    source = <<~RUBY
      class TestService
        def execute
          result = SomeAgent.run(input)
          render result.output
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to be >= 1
  end

  it "passes when .success? is checked" do
    source = <<~RUBY
      class TestService
        def execute
          result = SomeAgent.run(input)
          if result.success?
            render result.output
          end
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end
end
