# frozen_string_literal: true

require "backpressure/checks/ai/prompt_safety/no_input_sanitization"

RSpec.describe Backpressure::Checks::AI::PromptSafety::NoInputSanitization do
  def run_check(source, file_path: "app/ai/agents/test.rb")
    context = Backpressure::Contexts::AstContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags string interpolation in def user" do
    source = <<~RUBY
      class TestAgent
        def user
          "Analyze this: \#{@input}"
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("user")
  end

  it "passes when no interpolation in user method" do
    source = <<~RUBY
      class TestAgent
        def user
          "Analyze this static prompt"
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "ignores non-user methods" do
    source = <<~RUBY
      class TestAgent
        def system
          "System prompt with \#{@data}"
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end
end
