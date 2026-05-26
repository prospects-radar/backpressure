# Writing Extensions for Backpressure

This guide covers every extension point in Backpressure: custom checks, AI checks, YAML checks, context types, formatters, AI providers, AI strategies, corrections, and plugins.

---

## Table of Contents

- [Overview of Extension Points](#overview-of-extension-points)
- [Writing a Custom Check (Ruby DSL)](#writing-a-custom-check-ruby-dsl)
  - [Minimal check](#minimal-check)
  - [AST check](#ast-check)
  - [Group check (multi-file)](#group-check-multi-file)
  - [Project-wide check](#project-wide-check)
  - [Auto-correctable check](#auto-correctable-check)
  - [Compilable check (RuboCop cop)](#compilable-check-rubocop-cop)
- [Writing an AI Check (Ruby DSL)](#writing-an-ai-check-ruby-dsl)
- [Writing a YAML Check](#writing-a-yaml-check)
- [Writing a Custom Context Type](#writing-a-custom-context-type)
- [Writing a Custom Formatter](#writing-a-custom-formatter)
- [Writing a Custom AI Provider](#writing-a-custom-ai-provider)
- [Writing a Custom AI Strategy](#writing-a-custom-ai-strategy)
- [Writing a Custom Correction Type](#writing-a-custom-correction-type)
- [Bundling Extensions as a Plugin](#bundling-extensions-as-a-plugin)
- [Testing Your Extensions](#testing-your-extensions)
- [Best Practices](#best-practices)

---

## Overview of Extension Points

| Extension Point | Base Class / Registration | Use Case |
|---|---|---|
| Check (deterministic) | `Backpressure::Check` | Ruby/AST-based lint rules |
| AI check | `Backpressure::AiCheck` | LLM-powered semantic checks |
| YAML check | `.check.yml` file | AI checks without Ruby |
| Context type | `context :name` in plugin | New data shapes for checks |
| Formatter | `Backpressure::Formatters::Base` | New output formats |
| AI provider | `Backpressure::AI::Provider` | New LLM backends |
| AI strategy | Custom class | Pre-filtering, consensus, escalation |
| Correction | `Backpressure::Correction` | New auto-fix types |
| Plugin | `Backpressure.register_plugin` | Bundle multiple extensions |

---

## Writing a Custom Check (Ruby DSL)

Place check files anywhere in your configured `check_paths`. Each file must define exactly one class that inherits from `Backpressure::Check`.

### Minimal check

```ruby
# checks/frozen_string_literal_check.rb

class FrozenStringLiteralCheck < Backpressure::Check
  category :style
  severity :warning
  files "**/*.rb"
  requires :source

  def check(context)
    first_line = context.line(1)
    return if first_line&.include?("# frozen_string_literal: true")

    violation(
      OpenStruct.new(line: 1, column: 0),
      "Missing frozen_string_literal magic comment",
      auto_correctable: true,
      correction: Backpressure::Corrections::Insert.new(
        line: 1,
        text: "# frozen_string_literal: true\n",
        position: :before
      )
    )
  end
end
```

### AST check

Use `requires :ast` to get a fully parsed RuboCop-compatible AST. The `context.ast` object is a `RuboCop::AST::Node` with full traversal support.

```ruby
# checks/no_rescue_exception_check.rb

class NoRescueExceptionCheck < Backpressure::Check
  category :reliability
  severity :error
  files "app/**/*.rb"
  requires :ast

  def check(context)
    context.ast.each_node(:resbody) do |resbody|
      exception_types = resbody.children.first
      next unless exception_types

      exception_types.each_node(:const) do |const|
        if const.children.last == :Exception
          violation(
            resbody,
            "Rescuing Exception is too broad — rescue StandardError or a specific error class",
            auto_correctable: false
          )
        end
      end
    end
  end
end
```

Common AST node types you'll use:

| Node type | Ruby construct |
|---|---|
| `:class` | `class Foo` |
| `:module` | `module Foo` |
| `:def` | Method definition |
| `:send` | Method call |
| `:const` | Constant reference |
| `:ivasgn` | Instance variable assignment |
| `:lvasgn` | Local variable assignment |
| `:resbody` | `rescue` clause |
| `:str`, `:sym` | String/symbol literals |

Refer to the [RuboCop AST documentation](https://rubocop.github.io/rubocop-ast/) for full node reference.

### Group check (multi-file)

`GroupContext` gives a check access to multiple related files at once. Declare the roles your check needs:

```ruby
# checks/model_factory_pair_check.rb

class ModelFactoryPairCheck < Backpressure::Check
  category :testing
  severity :warning
  files "app/models/**/*.rb"
  requires :group

  # Declares the roles this check expects.
  # The runner resolves them by convention (model path → factory path).
  group_roles primary: :model, secondary: :factory

  def check(context)
    model_name  = File.basename(context.file_path, ".rb")
    factory_ctx = context.group[:factory]

    if factory_ctx.nil?
      violation(
        OpenStruct.new(line: 1, column: 0),
        "Model #{model_name} has no corresponding FactoryBot factory"
      )
      return
    end

    unless factory_ctx.source.include?("factory :#{model_name}")
      violation(
        OpenStruct.new(line: 1, column: 0),
        "Factory for #{model_name} does not define a :#{model_name} factory"
      )
    end
  end
end
```

### Project-wide check

`ProjectContext` gives checks access to the `ProjectIndex`, which catalogs all classes in the project. Use this for invariants that span many files.

```ruby
# checks/service_test_coverage_check.rb

class ServiceTestCoverageCheck < Backpressure::Check
  category :testing
  severity :warning
  files "app/services/**/*.rb"
  requires :project

  def check(context)
    service_name = context.source.match(/class\s+(\w+Service)/)&.captures&.first
    return unless service_name

    spec_path = "spec/services/#{service_name.gsub(/([A-Z])/, '_\1').downcase.delete_prefix('_')}_spec.rb"
    return if File.exist?(spec_path)

    violation(
      OpenStruct.new(line: 1, column: 0),
      "#{service_name} has no corresponding spec at #{spec_path}"
    )
  end
end
```

### Auto-correctable check

Attach a `Correction` to the violation call:

```ruby
# checks/trailing_whitespace_check.rb

class TrailingWhitespaceCheck < Backpressure::Check
  category :style
  severity :info
  files "**/*.rb"
  requires :source

  def check(context)
    context.lines.each_with_index do |line, index|
      line_number = index + 1
      next unless line.match?(/\s+$/)

      violation(
        OpenStruct.new(line: line_number, column: line.rstrip.length),
        "Trailing whitespace",
        auto_correctable: true,
        correction: Backpressure::Corrections::Replace.new(
          line: line_number,
          original: line,
          replacement: line.rstrip + "\n"
        )
      )
    end
  end
end
```

### Compilable check (RuboCop cop)

Mark a check `compilable` to allow generating a native RuboCop cop:

```ruby
class NoSystemCallCheck < Backpressure::Check
  category :security
  severity :error
  files "**/*.rb"
  requires :ast
  compilable                 # ← enables `backpressure compile`

  def check(context)
    context.ast.each_node(:send) do |node|
      next unless node.method_name == :system

      violation(
        node,
        "Use SafeShell.run instead of system()",
        auto_correctable: false
      )
    end
  end
end
```

Compile:

```
backpressure compile --output-dir .rubocop_cops/
```

---

## Writing an AI Check (Ruby DSL)

Inherit from `Backpressure::AiCheck` and use `ai_config` + `prompt_template`:

```ruby
# checks/doc_comment_quality_check.rb

class DocCommentQualityCheck < Backpressure::AiCheck
  category :documentation
  severity :info
  files "lib/**/*.rb"
  requires :source

  ai_config(
    provider: :openai,
    model: "gpt-4o-mini",
    temperature: 0.0,
    max_tokens: 1024
  )

  prompt_template <<~PROMPT
    You are a Ruby documentation reviewer. Examine the following Ruby file
    and identify any public methods that lack meaningful YARD documentation
    or have documentation that only restates the method name.

    Return a JSON array of objects:
    [{"line": <integer>, "message": "<short description>"}]

    If the file has no issues, return an empty array [].

    SOURCE:
    {{source}}
  PROMPT
end
```

### How `AiCheck` works

1. `check(context)` is called by the Runner.
2. `{{source}}` in the template is replaced with `context.source`.
3. The configured provider's `complete` method is called with the rendered prompt.
4. Results (array of `{line:, message:}`) are passed to `interpret`, which creates `Violation` objects.
5. Cache is consulted before calling the provider (if caching is enabled).

### Overriding `interpret`

Override `interpret` for custom result shapes:

```ruby
def interpret(results, context)
  results.each do |result|
    node = OpenStruct.new(line: result["line_number"].to_i, column: 0)
    violation(node, result["issue"])
  end
end
```

---

## Writing a YAML Check

For AI checks that need no custom Ruby logic, use a `.check.yml` file:

```yaml
# checks/api_contract_check.check.yml

name: ApiContractCheck
category: api_quality
severity: warning
files: "app/controllers/api/**/*.rb"
requires:
  - source

ai:
  provider: openai
  model: gpt-4o-mini
  temperature: 0.0
  max_tokens: 2048
  strategy:
    type: consensus
    count: 3

prompt: |
  You are an API design reviewer. Check this Rails controller for:
  1. Actions that return 200 instead of 201 for resource creation
  2. Missing rescue_from for expected error classes
  3. Inconsistent JSON key naming (mix of camelCase and snake_case)

  Return a JSON array:
  [{"line": <int>, "message": "<short issue description>"}]

  CONTROLLER SOURCE:
  {{source}}
```

Load all YAML checks from a directory automatically by including that directory in `check_paths`:

```yaml
# backpressure.yml
check_paths:
  - checks/
```

Load programmatically:

```ruby
Backpressure::YamlLoader.load_all("checks/")
```

---

## Writing a Custom Context Type

Implement a context class and register it in a plugin:

```ruby
# lib/backpressure_graphql/schema_context.rb

module BackpressureGraphql
  class SchemaContext
    attr_reader :source, :file_path, :schema_document

    def initialize(source:, file_path:)
      @source = source
      @file_path = file_path
      @schema_document = GraphQL::Language::Parser.parse(source)
    end

    def self.from_file(path)
      new(source: File.read(path), file_path: path)
    end

    def types
      @schema_document.definitions.select { |d| d.is_a?(GraphQL::Language::Nodes::TypeDefinition) }
    end

    def mutations
      types.select { |t| t.name.end_with?("Mutation") }
    end
  end
end
```

Register it:

```ruby
Backpressure.register_plugin(:graphql) do
  context :graphql_schema do |source:, file_path:|
    BackpressureGraphql::SchemaContext.new(source: source, file_path: file_path)
  end

  checks_from File.join(__dir__, "checks")
end
```

Use in a check:

```ruby
class GraphqlMutationNamingCheck < Backpressure::Check
  category :graphql
  severity :error
  files "app/graphql/**/*.rb"
  requires :graphql_schema

  def check(context)
    context.mutations.each do |mutation|
      unless mutation.name.end_with?("Mutation")
        violation(
          OpenStruct.new(line: mutation.line, column: 0),
          "GraphQL mutation type '#{mutation.name}' must end with 'Mutation'"
        )
      end
    end
  end
end
```

---

## Writing a Custom Formatter

Implement `Backpressure::Formatters::Base`:

```ruby
# lib/backpressure_html/formatters/html.rb

module BackpressureHtml
  module Formatters
    class Html < Backpressure::Formatters::Base
      def format(violations)
        return "<p>No violations found.</p>" if violations.empty?

        rows = violations.map do |v|
          <<~HTML
            <tr class="severity-#{v.severity}">
              <td>#{v.file}:#{v.line}</td>
              <td>#{v.severity}</td>
              <td>#{v.check_name}</td>
              <td>#{CGI.escape_html(v.message)}</td>
            </tr>
          HTML
        end

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head><title>Backpressure Report</title></head>
          <body>
            <h1>Backpressure Report</h1>
            <p>#{violations.size} violation(s) found.</p>
            <table>
              <thead><tr><th>Location</th><th>Severity</th><th>Check</th><th>Message</th></tr></thead>
              <tbody>#{rows.join}</tbody>
            </table>
          </body>
          </html>
        HTML
      end
    end
  end
end
```

Register:

```ruby
Backpressure.register_plugin(:html_formatter) do
  formatter :html, BackpressureHtml::Formatters::Html
end
```

Use:

```
backpressure check --format html > report.html
```

---

## Writing a Custom AI Provider

Subclass `Backpressure::AI::Provider` and implement `#complete`:

```ruby
# lib/backpressure_vertex/ai/providers/vertex.rb

module BackpressureVertex
  class Provider < Backpressure::AI::Provider
    def initialize(config:)
      super
      @project_id  = config[:project_id] || ENV["GCP_PROJECT_ID"]
      @location    = config[:location] || "us-central1"
      @credentials = config[:credentials] || Google::Auth.get_application_default
    end

    def complete(prompt:, model:, temperature:, max_tokens:, schema:)
      client = Google::Cloud::AIPlatform::V1::PredictionService::Client.new
      request = build_request(prompt, model, temperature, max_tokens)
      response = client.predict(request)
      parse_response(response, schema)
    end

    private

    def build_request(prompt, model, temperature, max_tokens)
      # ... build the Vertex AI request
    end

    def parse_response(response, schema)
      # Must return Array<Hash> with at least :line and :message keys
      JSON.parse(response.predictions.first["content"]).map(&:to_h)
    end
  end
end

# Register the provider
Backpressure::AI::Provider.register(:vertex_ai, BackpressureVertex::Provider)
```

Configure in `backpressure.yml`:

```yaml
ai:
  default_provider: vertex_ai
  providers:
    vertex_ai:
      project_id: my-gcp-project
      location: us-central1
```

---

## Writing a Custom AI Strategy

A strategy is any object that wraps the provider call:

```ruby
# lib/my_strategies/confidence_threshold.rb

class ConfidenceThresholdStrategy
  def initialize(threshold:)
    @threshold = threshold
  end

  # Yields a block that calls the provider; filters results by confidence score
  def evaluate(&provider_call)
    results = provider_call.call
    results.select { |r| r[:confidence].to_f >= @threshold }
  end
end
```

Use it in a check:

```ruby
class MyAiCheck < Backpressure::AiCheck
  def check(context)
    strategy = ConfidenceThresholdStrategy.new(threshold: 0.8)
    provider = Backpressure::AI::Provider.for(:openai, config: ai_settings)

    strategy.evaluate do
      provider.complete(
        prompt: render_prompt(context.source),
        model: ai_settings[:model],
        temperature: ai_settings[:temperature],
        max_tokens: ai_settings[:max_tokens],
        schema: ai_settings[:schema]
      )
    end.each do |result|
      node = OpenStruct.new(line: result[:line].to_i, column: 0)
      violation(node, result[:message])
    end
  end
end
```

---

## Writing a Custom Correction Type

Subclass `Backpressure::Correction` and implement `apply(source)`:

```ruby
class SortLinesCorrection < Backpressure::Correction
  def initialize(start_line:, end_line:)
    super(line: start_line)
    @start_line = start_line
    @end_line   = end_line
  end

  def apply(source)
    lines = source.lines
    block = lines[(@start_line - 1)...@end_line]
    sorted_block = block.sort
    lines[(@start_line - 1)...@end_line] = sorted_block
    lines.join
  end
end
```

Use in a violation:

```ruby
violation(
  node,
  "These lines should be in alphabetical order",
  auto_correctable: true,
  correction: SortLinesCorrection.new(start_line: 5, end_line: 12)
)
```

---

## Bundling Extensions as a Plugin

Group all your extensions into a single plugin for clean distribution:

```ruby
# lib/backpressure_myapp.rb

require "backpressure"
require_relative "backpressure_myapp/contexts/graphql_schema_context"
require_relative "backpressure_myapp/formatters/slack"
require_relative "backpressure_myapp/ai/providers/vertex"

Backpressure.register_plugin(:myapp) do
  # Register all .rb and .check.yml files in the checks directory
  checks_from File.join(__dir__, "backpressure_myapp", "checks")

  # Register custom context types
  context :graphql_schema do |source:, file_path:|
    BackpressureMyapp::Contexts::GraphqlSchemaContext.new(source: source, file_path: file_path)
  end

  # Register custom formatters
  formatter :slack, BackpressureMyapp::Formatters::Slack

  # Custom AI providers register themselves via their own require
end
```

Distribute as a gem and activate in `backpressure.yml`:

```yaml
plugins:
  - backpressure_myapp
```

Or activate in your Gemfile:

```ruby
gem "backpressure_myapp"
```

And require it in an initializer/Rakefile before running Backpressure.

---

## Testing Your Extensions

Use RSpec with the Backpressure test helpers:

```ruby
# spec/checks/no_direct_http_check_spec.rb

require "backpressure"
require_relative "../../checks/no_direct_http_check"

RSpec.describe NoDirectHttpCheck do
  subject(:check) { described_class.new }

  def run_check(source, file: "app/services/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file)
    check.run(context)
    check.violations
  end

  it "detects Net::HTTP usage" do
    violations = run_check("response = Net::HTTP.get(uri)")
    expect(violations).to have(1).item
    expect(violations.first.message).to include("HttpClient")
  end

  it "allows HttpClient" do
    violations = run_check("response = HttpClient.get(url)")
    expect(violations).to be_empty
  end

  it "respects disable annotation" do
    violations = run_check("Net::HTTP.get(uri)  # backpressure:disable NoDirectHttp")
    expect(violations).to be_empty
  end
end
```

For AST checks, use `AstContext`:

```ruby
def run_check(source, file: "app/models/test.rb")
  context = Backpressure::Contexts::AstContext.new(source: source, file_path: file)
  check.run(context)
  check.violations
end
```

For AI checks, stub the provider:

```ruby
before do
  stub_provider = instance_double(Backpressure::AI::Provider)
  allow(stub_provider).to receive(:complete).and_return([
    { "line" => 5, "message" => "Ambiguous SHOULD" }
  ])
  allow(Backpressure::AI::Provider).to receive(:for).and_return(stub_provider)
end
```

---

## Best Practices

**Check authoring:**
- Keep each check focused on one rule; split multi-rule logic into separate classes.
- Use `:source` context unless you genuinely need AST parsing — it is faster.
- Always provide a `violation` message that tells the developer *what to do*, not just *what's wrong*.
- Set `auto_correctable: true` only when the correction is deterministically safe.

**AI checks:**
- Use `pre_filter` to skip files that clearly have no violations (reduces cost).
- Use `consensus` (count 3–5) for non-deterministic models; use `temperature: 0.0` for deterministic ones.
- Pin the model in your check or YAML; do not rely on `default_provider` defaults.
- Test AI checks with a recorded fixture response; never call real LLMs in tests.
- Keep prompts short. Token cost scales linearly with file size × strategy count.

**Performance:**
- Enable caching for all AI checks.
- Use `files` glob to restrict checks to only the paths they apply to — skipping irrelevant files is fast.
- For project-wide checks, build `ProjectIndex` once per run, not per file; the Runner handles this when `requires :project` is declared.

**Corrections:**
- Test corrections against real files, not just synthetic strings.
- Corrections must be idempotent: applying twice should produce the same result as applying once.
- For complex corrections (multi-line rewrites), prefer `Replace` over chaining multiple `Insert`/`Remove` operations.
