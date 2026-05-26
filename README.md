# Backpressure

A modular, extensible static-analysis framework for Ruby. Write custom checks in plain Ruby or YAML, run them against your codebase, auto-correct violations, and enforce quality gates in CI using a ratcheting baseline.

Backpressure fills the gaps that rule-based linters do not cover: cross-file invariants, AI-powered semantic checks, component-tree analysis, and project-wide quality ratcheting.

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration Reference](#configuration-reference)
- [CLI Reference](#cli-reference)
- [Writing Checks](#writing-checks)
  - [Ruby DSL Check](#ruby-dsl-check)
  - [YAML / AI Check](#yaml--ai-check)
- [Contexts](#contexts)
- [Violations and Severity](#violations-and-severity)
- [Auto-Corrections](#auto-corrections)
- [AI Integration](#ai-integration)
- [The Ratchet / Baseline System](#the-ratchet--baseline-system)
- [Caching](#caching)
- [Output Formats](#output-formats)
- [Inline Annotations](#inline-annotations)
- [Plugin System](#plugin-system)
- [RuboCop Compilation](#rubocop-compilation)
- [Integrating in CI](#integrating-in-ci)
- [Programmatic API](#programmatic-api)

---

## Installation

Add to your Gemfile:

```ruby
gem "backpressure", path: "vendor/local_gems/backpressure"
```

Or, once published to RubyGems:

```ruby
gem "backpressure"
```

Then run:

```
bundle install
```

---

## Quick Start

### 1. Initialize configuration

```
bundle exec backpressure init
```

This generates a `backpressure.yml` in your project root:

```yaml
check_paths:
  - checks/

include:
  - "app/**/*.rb"
  - "lib/**/*.rb"
exclude:
  - "vendor/**"

format: pretty

cache:
  enabled: true
  dir: .backpressure_cache

ratchet:
  baseline_file: backpressure_baseline.yml
  anti_tamper: true
```

### 2. Write your first check

Create `checks/no_direct_http_check.rb`:

```ruby
class NoDirectHttpCheck < Backpressure::Check
  category :architecture
  severity :error
  files "app/**/*.rb"
  requires :source

  def check(context)
    context.lines.each_with_index do |line, index|
      if line.include?("Net::HTTP") || line.include?("HTTParty")
        violation(
          OpenStruct.new(line: index + 1, column: 0),
          "Use the HttpClient service object instead of direct HTTP libraries"
        )
      end
    end
  end
end
```

### 3. Run checks

```
bundle exec backpressure check
```

Output (pretty format):

```
app/services/webhook_service.rb:14:0  [error] NoDirectHttp  Use the HttpClient service object instead of direct HTTP libraries

1 violation found (0 auto-correctable, 1 manual fix)
```

### 4. Set a baseline (for existing codebases)

Accept all current violations as known-good so CI only fails on new ones:

```
bundle exec backpressure check --update-baseline
```

Commit `backpressure_baseline.yml`. From now on, only new violations introduced after the baseline cause CI failure.

---

## Configuration Reference

All settings live in `backpressure.yml` (or a custom path passed to `--config`).

```yaml
# Directories to scan for check definition files (Ruby or YAML)
check_paths:
  - checks/
  - lib/checks/

# Glob patterns for files to analyze
include:
  - "app/**/*.rb"
  - "lib/**/*.rb"

# Glob patterns to skip
exclude:
  - "vendor/**"
  - "db/schema.rb"

# Output format: pretty | json
format: pretty

# AI provider settings
ai:
  default_provider: openai
  providers:
    openai:
      api_key: <%= ENV["OPENAI_API_KEY"] %>
      model: gpt-4o-mini
  tiers:
    cheap: openai
    quality: openai

# List of plugins to activate
plugins:
  - backpressure-graphql    # example third-party plugin

# Result caching (for AI checks)
cache:
  enabled: true
  dir: .backpressure_cache

# Ratchet (baseline) settings
ratchet:
  baseline_file: backpressure_baseline.yml
  anti_tamper: true   # fail if baseline was manually inflated

# Per-check overrides
checks:
  NoDirectHttp:
    enabled: false        # disable a specific check
  ComponentHierarchy:
    severity: warning     # override severity
```

### Configuration precedence

Global defaults → category-level → per-check `checks:` overrides → inline `# backpressure:disable` annotations.

---

## CLI Reference

```
backpressure [command] [options] [paths...]
```

### `backpressure check`

Run all checks against configured (or specified) paths.

```
backpressure check                            # use configured includes
backpressure check app/models/user.rb        # single file
backpressure check app/models/               # directory
backpressure check --only NoDirectHttp       # run one check
backpressure check --format json             # JSON output
backpressure check --update-baseline         # write new baseline
backpressure check --no-cache                # skip cache
backpressure check --ai-fix                  # apply AI-suggested corrections
backpressure check --dry-run                 # preview without writing
backpressure check --interactive             # confirm each fix
```

| Option | Description |
|---|---|
| `--only CHECK` | Comma-separated check names to run |
| `--format FORMAT` | `pretty` (default) or `json` |
| `--update-baseline` | Write all current violations to the baseline file |
| `--no-cache` | Bypass cache (useful in CI when cache warm-up is undesirable) |
| `--ai-fix` | Apply AI-generated corrections (in addition to deterministic ones) |
| `--interactive` | Prompt before each correction |
| `--dry-run` | Show what would be fixed without writing |
| `--config FILE` | Path to config file (default: `backpressure.yml`) |

### `backpressure list`

Print all registered checks with their category and severity.

```
$ backpressure list

NoDirectHttp        architecture  error
ComponentHierarchy  design        warning
PromptClarity       ai            warning
```

### `backpressure init`

Generate a default `backpressure.yml` in the current directory.

### `backpressure fix`

Apply deterministic auto-corrections for all correctable violations. *(Coming soon — use `check --ai-fix` for now.)*

### `backpressure cache`

Manage the result cache. *(Coming soon.)*

### `backpressure compile`

Compile compilable checks into RuboCop cops. *(See [RuboCop Compilation](#rubocop-compilation).)*

---

## Writing Checks

### Ruby DSL Check

All checks inherit from `Backpressure::Check` and implement `#check(context)`.

```ruby
class MyCheck < Backpressure::Check
  # Required metadata
  category :architecture          # any symbol you choose
  severity :error                 # :error | :warning | :info
  files "app/**/*.rb"             # glob – omit to run on all files
  requires :ast                   # :source (default) | :ast | :group | :project

  # Optional: restrict to compilable RuboCop cop
  # compilable

  def check(context)
    # context is AstContext (because requires :ast)
    context.ast.each_node(:send) do |node|
      if node.method_name == :system
        violation(
          node,
          "Do not use `system` — use SafeShell instead",
          auto_correctable: false
        )
      end
    end
  end
end
```

#### Class-level DSL methods

| Method | Description |
|---|---|
| `category(sym)` | Logical grouping (`:architecture`, `:performance`, etc.) |
| `severity(sym)` | `:error`, `:warning`, or `:info` |
| `files(glob)` | Restrict this check to matching paths |
| `requires(*syms)` | Context(s) needed: `:source`, `:ast`, `:group`, `:project` |
| `ratchet(mode)` | Override ratchet mode (default `:strict`) |
| `compilable` | Mark as compilable to a RuboCop cop |

#### Instance methods inside `check`

| Method | Description |
|---|---|
| `violation(node, message, auto_correctable:, correction:)` | Record a violation |
| `skip(reason)` | Stop processing this file for this check |

---

### YAML / AI Check

For AI-powered semantic checks, write a `.check.yml` file in your `check_paths` directory. The `YamlLoader` turns it into an `AiCheck` subclass automatically.

```yaml
# checks/prompt_clarity.check.yml

name: PromptClarity
category: ai_quality
severity: warning
files: "lib/prompts/**/*.rb"
requires:
  - source

ai:
  provider: openai
  model: gpt-4o-mini
  temperature: 0.1
  max_tokens: 1024
  strategy:
    type: consensus
    count: 3

prompt: |
  You are a senior engineer reviewing AI prompt files.
  Identify any requirements that violate RFC 2119 (MUST/SHOULD/MAY usage).

  Return a JSON array of objects with keys:
    - line: integer (1-based line number)
    - message: string (short description of the problem)

  Source:
  {{source}}
```

| YAML key | Type | Description |
|---|---|---|
| `name` | string | Check class name |
| `category` | symbol | Logical category |
| `severity` | symbol | `:error`, `:warning`, `:info` |
| `files` | glob | File filter |
| `requires` | array | Context dependencies |
| `ai.provider` | symbol | Registered provider name |
| `ai.model` | string | LLM model identifier |
| `ai.temperature` | float | LLM temperature |
| `ai.max_tokens` | integer | Max completion tokens |
| `ai.timeout` | integer | Seconds before timeout |
| `ai.strategy` | hash | Strategy config (see [AI Integration](#ai-integration)) |
| `ai.schema` | hash | Expected structured output schema |
| `prompt` | string | Prompt template; `{{source}}` is replaced with file content |

---

## Contexts

A check declares what data it needs via `requires`. The Runner injects the matching context.

### `:source` — `SourceContext`

Default. Provides raw source text and line utilities.

```ruby
context.source          # full file content string
context.file_path       # absolute path to the file
context.lines           # array of lines (String)
context.line_count      # count of non-empty lines
context.line(3)         # 1-based line access → String
```

Construct from a file:

```ruby
ctx = Backpressure::Contexts::SourceContext.from_file("/path/to/file.rb")
```

### `:ast` — `AstContext`

Provides a parsed RuboCop-compatible AST. Inherits all `:source` methods.

```ruby
context.ast              # RuboCop::AST::Node (root)
context.processed_source # RuboCop::AST::ProcessedSource

# Traverse the AST
context.ast.each_node(:class) do |node|
  # node is a RuboCop::AST::Node
end
```

Construct from a file:

```ruby
ctx = Backpressure::Contexts::AstContext.from_file("/path/to/file.rb")
```

### `:group` — `GroupContext`

For checks that compare multiple related files (e.g., model + factory pair).

```ruby
context.file_path         # path of the primary file
context.source            # source of the primary file
context.group[:model]     # SourceContext for the :model role
context.group[:factory]   # SourceContext for the :factory role (nil if absent)
```

### `:project` — `ProjectContext`

For whole-project invariants. Provides a `ProjectIndex` and the current file being analyzed.

```ruby
context.project           # Backpressure::ProjectIndex instance
context.file_path         # current file
context.source            # current file content

# ProjectIndex API
context.project.classes                       # all ClassEntry structs
context.project.classes_in("app/models/**")  # filtered by glob
context.project.classes_matching(/Service$/) # filtered by regex
context.project.references_to(["UserService", "PaymentService"])
# → [{file:, node:, target:}, ...]
```

---

## Violations and Severity

Record a violation inside `#check(context)`:

```ruby
violation(
  node,                                     # AST node or OpenStruct with .line / .column
  "Message describing the problem",
  auto_correctable: true,                   # default false
  correction: Backpressure::Corrections::Replace.new(
    line: node.loc.line,
    original: "bad_method",
    replacement: "good_method"
  )
)
```

Severities:

| Symbol | Meaning |
|---|---|
| `:error` | Hard failure; blocks CI |
| `:warning` | Reported but does not fail CI by default |
| `:info` | Informational; never fails CI |

---

## Auto-Corrections

Corrections are attached to violations and applied by `backpressure fix` (or `check --ai-fix`).

### Replace

Substitutes a string on a specific line:

```ruby
Backpressure::Corrections::Replace.new(
  line: 14,
  original: "Net::HTTP.get",
  replacement: "HttpClient.get"
)
```

### Insert

Inserts text before or after a line:

```ruby
Backpressure::Corrections::Insert.new(
  line: 1,
  text: "# frozen_string_literal: true\n",
  position: :before  # or :after
)
```

### Remove

Deletes an entire line:

```ruby
Backpressure::Corrections::Remove.new(line: 23)
```

All corrections implement `apply(source) → String`, returning the corrected source.

---

## AI Integration

### Configuring a provider

Register providers in `backpressure.yml` under `ai.providers`:

```yaml
ai:
  default_provider: openai
  providers:
    openai:
      api_key: <%= ENV["OPENAI_API_KEY"] %>
      model: gpt-4o-mini
```

Or register programmatically:

```ruby
Backpressure::AI::Provider.register(:my_provider, MyProviderClass)
```

A provider class must implement `#complete`:

```ruby
class MyProvider < Backpressure::AI::Provider
  def complete(prompt:, model:, temperature:, max_tokens:, schema:)
    # call your LLM API
    # return Array of hash-like objects with :line and :message keys
    []
  end
end
```

### Writing a Ruby AI check

```ruby
class PromptClarityCheck < Backpressure::AiCheck
  category :ai_quality
  severity :warning
  files "lib/prompts/**/*.rb"
  requires :source

  ai_config(
    provider: :openai,
    model: "gpt-4o-mini",
    temperature: 0.1,
    max_tokens: 512
  )

  prompt_template <<~PROMPT
    Review this Ruby file for any AI prompt strings that violate RFC 2119.
    Return JSON: [{line: <int>, message: <str>}]

    {{source}}
  PROMPT
end
```

### AI Strategies

Strategies are composable modifiers that control how AI checks run.

#### `consensus`

Runs the check N times and keeps only violations that appear in the majority of runs. Useful when the model is non-deterministic.

```yaml
ai:
  strategy:
    type: consensus
    count: 5          # run 5 times; keep violations appearing ≥3 times
```

Programmatically:

```ruby
strategy = Backpressure::AI::Strategies::Consensus.new(count: 5)
results = strategy.evaluate { |_run_index| provider.complete(...) }
agreed = results.select { |r| r[:agreed] }
```

#### `pre_filter`

Skips the AI call entirely if the source does not match a pattern. Saves cost for files unlikely to have violations.

```yaml
ai:
  strategy:
    type: pre_filter
    pattern: "MUST|SHOULD|SHALL"   # regex or literal string
```

Programmatically:

```ruby
filter = Backpressure::AI::Strategies::PreFilter.new(pattern: /MUST|SHOULD/)
provider.complete(...) if filter.should_run?(context.source)
```

---

## The Ratchet / Baseline System

The ratchet prevents new violations from slipping in while allowing pre-existing ones to be fixed incrementally.

### How it works

1. `backpressure check --update-baseline` records all current violations to `backpressure_baseline.yml`.
2. In CI, `backpressure check` compares current violations against the baseline.
3. Only violations not in the baseline cause a non-zero exit code.
4. As you fix old violations, the count in the baseline shrinks. If someone re-introduces a fixed violation, `anti_tamper: true` detects it and fails.

### Baseline file format

```yaml
NoDirectHttp:
  count: 3
  files:
    - app/services/webhook_service.rb:14
    - app/controllers/api_controller.rb:22
    - lib/integrations/stripe.rb:8
```

### Workflow

```bash
# Accept existing violations
bundle exec backpressure check --update-baseline
git add backpressure_baseline.yml
git commit -m "chore: accept existing backpressure violations"

# Reduce violations over time
# edit files, fix violations…
bundle exec backpressure check --update-baseline   # update baseline to reflect fewer violations
git add backpressure_baseline.yml
git commit -m "fix: resolve NoDirectHttp violations in webhook_service"
```

---

## Caching

The cache persists AI check results to disk keyed by `(check_version, file_path, file_content_hash)`. Repeated runs on unchanged files skip the LLM call entirely.

```yaml
cache:
  enabled: true
  dir: .backpressure_cache    # gitignore this directory
```

Use in CI: restore the cache directory between builds (e.g., via GitHub Actions `actions/cache`) keyed on `backpressure.yml` and check file hashes.

Bypass for a run:

```
backpressure check --no-cache
```

Access the cache API programmatically:

```ruby
cache = Backpressure::Cache.new(dir: ".backpressure_cache")
cached = cache.fetch(check_name: "PromptClarity", file_path: path, file_content: src, check_version: "1")
cache.store(check_name: "PromptClarity", file_path: path, file_content: src, check_version: "1", result: violations)
cache.stats   # => {entries: 42, total_bytes: 18432}
cache.clear
```

---

## Output Formats

### Pretty (default)

Human-readable, coloured output grouped by violation.

```
app/services/webhook_service.rb:14:0  [error] NoDirectHttp  Use the HttpClient service object
app/controllers/api_controller.rb:22:4  [warning] PromptClarity  Ambiguous SHOULD usage

2 violations found (0 auto-correctable, 2 manual fix)
```

### JSON

Machine-readable; suitable for dashboard ingestion or downstream tooling.

```
backpressure check --format json
```

```json
[
  {
    "check_name": "NoDirectHttp",
    "category": "architecture",
    "severity": "error",
    "message": "Use the HttpClient service object",
    "file": "app/services/webhook_service.rb",
    "line": 14,
    "column": 0,
    "auto_correctable": false
  }
]
```

---

## Inline Annotations

Suppress a specific check on a line with an inline comment:

```ruby
response = Net::HTTP.get(uri)  # backpressure:disable NoDirectHttp
```

Suppress multiple checks:

```ruby
result = system("ls")  # backpressure:disable NoSystemCall,ShellInjection
```

---

## Plugin System

Plugins register additional checks, formatters, and context types without modifying the core.

### Creating a plugin

```ruby
# lib/backpressure_graphql.rb
Backpressure.register_plugin(:graphql) do
  # Load all checks from a directory
  checks_from File.join(__dir__, "checks")

  # Register a custom formatter
  formatter :html, Backpressure::Formatters::Html

  # Register a custom context type
  context :graphql_schema do |source:, file_path:|
    BackpressureGraphql::SchemaContext.new(source: source, file_path: file_path)
  end
end
```

### Activating plugins

In `backpressure.yml`:

```yaml
plugins:
  - backpressure_graphql
```

Or programmatically before running:

```ruby
require "backpressure_graphql"
```

### Plugin DSL methods

| Method | Description |
|---|---|
| `checks_from(directory)` | Load and register all `*.rb` and `*.check.yml` files in directory |
| `formatter(name, klass)` | Register a formatter class under a name |
| `context(name, &block)` | Register a context builder block |

---

## RuboCop Compilation

Checks that require only `:ast` context and are marked `compilable` can be compiled into native RuboCop cops. This gives inline editor squiggles without duplicating logic.

### Mark a check as compilable

```ruby
class NoSystemCallCheck < Backpressure::Check
  category :security
  severity :error
  requires :ast
  compilable

  def check(context)
    context.ast.each_node(:send) do |node|
      violation(node, "Avoid system() — use SafeShell") if node.method_name == :system
    end
  end
end
```

### Compile to a RuboCop cop

```
backpressure compile --output-dir .rubocop_cops/
```

The generated file (`.rubocop_cops/no_system_call.rb`) wraps your check logic in a `RuboCop::Cop::Base` subclass. Reference it in `.rubocop.yml`:

```yaml
require:
  - ./.rubocop_cops/no_system_call

Custom/NoSystemCall:
  Enabled: true
```

---

## Integrating in CI

### GitHub Actions

```yaml
- name: Run Backpressure
  run: bundle exec backpressure check --format json | tee backpressure.json
  
- name: Upload results
  uses: actions/upload-artifact@v4
  with:
    name: backpressure-results
    path: backpressure.json
```

Fail the build on new violations (exit code non-zero when violations exceed baseline):

```yaml
- name: Backpressure check
  run: bundle exec backpressure check
```

### Cache in CI

```yaml
- uses: actions/cache@v4
  with:
    path: .backpressure_cache
    key: backpressure-${{ hashFiles('backpressure.yml', 'checks/**') }}
```

---

## Programmatic API

Embed Backpressure in other Ruby tools or Rake tasks:

```ruby
require "backpressure"

Backpressure.configure do |config|
  config.check_paths = ["checks/"]
  config.include_patterns = ["app/**/*.rb"]
  config.format = :json
end

runner = Backpressure::Runner.new
result = runner.run

result.violations.each do |v|
  puts "#{v.file}:#{v.line} [#{v.severity}] #{v.check_name}: #{v.message}"
end

puts "Skipped #{result.skipped} checks"

exit(result.violations.any? ? 1 : 0)
```

### Building a project index manually

```ruby
index = Backpressure::ProjectIndex.build(Dir.glob("app/**/*.rb"))

# Find all service classes
services = index.classes_matching(/Service$/)

# Find files referencing PaymentGateway
refs = index.references_to(["PaymentGateway"])
refs.each { |r| puts "#{r.file}: references #{r.target}" }
```
