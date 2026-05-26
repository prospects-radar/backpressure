# Writing Rules (Checks) for Backpressure

Rules in Backpressure are called **checks**. This guide covers all supported formats for writing checks, from simple line-pattern rules to AI-powered semantic analysis, along with detailed examples, patterns, and format-specific details.

---

## Table of Contents

- [Check Formats Overview](#check-formats-overview)
- [Format 1: Source-Based Rule (`:source` context)](#format-1-source-based-rule-source-context)
- [Format 2: AST-Based Rule (`:ast` context)](#format-2-ast-based-rule-ast-context)
- [Format 3: Multi-File Rule (`:group` context)](#format-3-multi-file-rule-group-context)
- [Format 4: Project-Wide Rule (`:project` context)](#format-4-project-wide-rule-project-context)
- [Format 5: AI Rule (Ruby DSL)](#format-5-ai-rule-ruby-dsl)
- [Format 6: AI Rule (YAML)](#format-6-ai-rule-yaml)
- [Recording Violations](#recording-violations)
- [Skipping a Check](#skipping-a-check)
- [Corrections (Auto-Fix)](#corrections-auto-fix)
- [Ratchet Configuration per Check](#ratchet-configuration-per-check)
- [Configuration Overrides in YAML](#configuration-overrides-in-yaml)
- [Check Naming Conventions](#check-naming-conventions)
- [Complete Examples by Domain](#complete-examples-by-domain)
  - [Architecture enforcement](#architecture-enforcement)
  - [Testing invariants](#testing-invariants)
  - [Component tree rules](#component-tree-rules)
  - [AI prompt quality](#ai-prompt-quality)
  - [API design](#api-design)

---

## Check Formats Overview

| Format | File extension | Context | Best for |
|---|---|---|---|
| Source-based Ruby | `.rb` | `:source` | Line patterns, text searches, count thresholds |
| AST-based Ruby | `.rb` | `:ast` | Structural Ruby analysis (method calls, inheritance, etc.) |
| Multi-file Ruby | `.rb` | `:group` | Paired-file invariants (model+factory, migration+schema, etc.) |
| Project-wide Ruby | `.rb` | `:project` | Cross-codebase invariants, orphan detection |
| AI Ruby | `.rb` | `:source` or `:ast` | Semantic checks requiring reasoning |
| AI YAML | `.check.yml` | `:source` | AI checks without writing Ruby |

---

## Format 1: Source-Based Rule (`:source` context)

Use `requires :source` (or omit `requires`, since it is the default) when you need raw text access.

```ruby
# checks/no_hardcoded_urls_check.rb

class NoHardcodedUrlsCheck < Backpressure::Check
  category :maintainability
  severity :warning
  files "app/**/*.rb"
  requires :source

  PATTERN = %r{https?://(?!example\.test)[a-zA-Z0-9./_\-?=&%]+}

  def check(context)
    context.lines.each_with_index do |line, index|
      next if line.strip.start_with?("#")  # skip comments

      matches = line.scan(PATTERN)
      matches.each do |url|
        violation(
          OpenStruct.new(line: index + 1, column: line.index(url) || 0),
          "Hardcoded URL '#{url}' — extract to a constant or configuration"
        )
      end
    end
  end
end
```

### SourceContext API

```ruby
context.source          # full file content as String
context.file_path       # absolute path
context.lines           # Array of String lines (with newlines)
context.line_count      # count of non-empty lines
context.line(n)         # 1-based String line access
```

### When to use `:source`

- Regex pattern matching across lines
- Counting occurrences (method calls by name, keyword frequency)
- Checking file-level conventions (magic comments, copyright headers)
- Structural text constraints (max line count, max method count estimated by `def` keyword count)

---

## Format 2: AST-Based Rule (`:ast` context)

Use `requires :ast` to parse the file into a RuboCop-compatible AST for structural analysis.

```ruby
# checks/no_private_attr_reader_check.rb

class NoPrivateAttrReaderCheck < Backpressure::Check
  category :style
  severity :info
  files "app/**/*.rb"
  requires :ast

  def check(context)
    inside_private = false

    context.ast.each_node do |node|
      if node.type == :send && node.children[1] == :private && node.children[0].nil?
        inside_private = true
      end

      if inside_private && node.type == :send && node.children[1] == :attr_reader
        violation(
          node,
          "Prefer explicit private method definitions over `private attr_reader`"
        )
      end
    end
  end
end
```

### AstContext API

```ruby
context.source            # String
context.file_path         # String
context.ast               # RuboCop::AST::Node (root)
context.processed_source  # RuboCop::AST::ProcessedSource
context.lines             # Array<String>
context.line(n)           # String

# Traversal
context.ast.each_node(:send) { |n| ... }   # filter by type
context.ast.each_node { |n| ... }          # all nodes
```

### Useful node types

| Type | Ruby construct | Common children |
|---|---|---|
| `:class` | `class Foo < Bar` | `[name, superclass, body]` |
| `:module` | `module Foo` | `[name, body]` |
| `:def` | `def foo(a, b)` | `[method_name, args, body]` |
| `:defs` | `def self.foo` | `[self, method_name, args, body]` |
| `:send` | `obj.method(args)` | `[receiver, method_name, *args]` |
| `:const` | `Foo::Bar` | `[scope, name]` |
| `:block` | `do...end` block | `[send, args, body]` |
| `:if` | `if/unless` | `[condition, truthy, falsy]` |
| `:resbody` | `rescue ErrorClass => e` | `[exc_types, var, body]` |
| `:ivasgn` | `@foo = value` | `[name, value]` |
| `:str` | `"hello"` | `[value]` |
| `:sym` | `:hello` | `[value]` |
| `:array` | `[a, b, c]` | `[*elements]` |
| `:hash` | `{a: 1}` | `[*pairs]` |

### Extracting location from a node

```ruby
node.loc.line          # Integer
node.loc.column        # Integer
node.loc.expression    # source range string

# For violation:
violation(node, "message")  # Backpressure extracts line/column from node.loc
```

### Pattern: finding method definitions

```ruby
context.ast.each_node(:def) do |node|
  method_name = node.children[0]  # Symbol
  args_node   = node.children[1]  # s(:args, ...)
  body        = node.children[2]

  if method_name.to_s.start_with?("get_")
    violation(node, "Method name should not start with 'get_' — use the noun directly")
  end
end
```

### Pattern: checking inheritance

```ruby
context.ast.each_node(:class) do |node|
  class_name_node = node.children[0]
  superclass_node = node.children[1]

  class_name = class_name_node.children.last
  superclass  = superclass_node&.children&.last

  if superclass == :ApplicationRecord && class_name.to_s.end_with?("Service")
    violation(node, "Service objects must not inherit from ApplicationRecord")
  end
end
```

### Pattern: detecting method calls

```ruby
context.ast.each_node(:send) do |node|
  receiver    = node.children[0]
  method_name = node.children[1]
  args        = node.children[2..]

  next unless method_name == :sleep

  violation(node, "Do not call sleep() in production code")
end
```

---

## Format 3: Multi-File Rule (`:group` context)

Use `requires :group` when a check needs to compare a primary file with one or more related files.

```ruby
# checks/model_factory_check.rb

class ModelFactoryCheck < Backpressure::Check
  category :testing
  severity :warning
  files "app/models/**/*.rb"
  requires :group

  def check(context)
    model_name    = File.basename(context.file_path, ".rb")
    factory_file  = "spec/factories/#{model_name.pluralize}.rb"
    factory_ctx   = context.group[:factory]

    if factory_ctx.nil?
      violation(
        OpenStruct.new(line: 1, column: 0),
        "Model #{model_name} is missing a FactoryBot factory at #{factory_file}"
      )
      return
    end

    unless factory_ctx.source.include?("factory :#{model_name}")
      violation(
        OpenStruct.new(line: 1, column: 0),
        "Factory file #{factory_file} does not define a :#{model_name} factory"
      )
    end
  end
end
```

### GroupContext API

```ruby
context.file_path          # primary file path (String)
context.source             # primary file content (String)
context.group              # Hash<Symbol, SourceContext|nil>
context.group[:factory]    # SourceContext or nil if file absent
context.group[:factory]&.source  # safe access
context.group[:factory]&.lines
```

Role resolution is convention-based — the Runner derives companion file paths from the primary file path using registered role resolvers. See [writing-extensions.md](writing-extensions.md) for how to define custom role resolvers.

---

## Format 4: Project-Wide Rule (`:project` context)

Use `requires :project` for invariants that span the entire codebase.

```ruby
# checks/no_orphan_service_check.rb

class NoOrphanServiceCheck < Backpressure::Check
  category :architecture
  severity :warning
  files "app/services/**/*.rb"
  requires :project

  def check(context)
    service_class = context.source.match(/class\s+(\w+)/)&.captures&.first
    return unless service_class

    callers = context.project.references_to([service_class])
    return if callers.any?

    violation(
      OpenStruct.new(line: 1, column: 0),
      "#{service_class} is never referenced — it may be dead code"
    )
  end
end
```

### ProjectContext API

```ruby
context.file_path   # current file being analyzed
context.source      # current file content
context.project     # Backpressure::ProjectIndex

# ProjectIndex
context.project.classes                        # Array<ClassEntry>
context.project.classes_in("app/models/**")   # Array<ClassEntry> filtered by glob
context.project.classes_matching(/Service$/)  # Array<ClassEntry> filtered by regex
context.project.references_to(["FooService"]) # Array<{file:, node:, target:}>

# ClassEntry
entry.name             # String class name
entry.file             # String file path
entry.node             # RuboCop::AST::Node
entry.superclass_name  # String or nil
```

The `ProjectIndex` is built once per runner invocation and shared across all project checks. Do not call `ProjectIndex.build` yourself inside a check.

---

## Format 5: AI Rule (Ruby DSL)

Inherit from `Backpressure::AiCheck` for full Ruby control over the AI pipeline.

```ruby
# checks/rfc2119_compliance_check.rb

class Rfc2119ComplianceCheck < Backpressure::AiCheck
  category :ai_quality
  severity :warning
  files "lib/prompts/**/*.rb"
  requires :source

  ai_config(
    provider: :openai,
    model: "gpt-4o-mini",
    temperature: 0.0,
    max_tokens: 1024
  )

  prompt_template <<~PROMPT
    You are a technical writing reviewer specialising in RFC 2119 compliance.

    Review the following Ruby file. It contains AI prompt strings.
    Identify any requirements expressed with RFC 2119 keywords (MUST, SHOULD, SHALL,
    MAY, MUST NOT, SHOULD NOT) that are ambiguous, contradictory, or incorrectly
    used.

    Return a JSON array of objects. Each object must have:
      - "line": integer (1-based line number in the file)
      - "message": string (concise description of the violation)

    If there are no issues, return an empty array [].

    FILE CONTENT:
    {{source}}
  PROMPT
end
```

### AiCheck class-level DSL

```ruby
ai_config(
  provider: :openai,       # registered provider name
  model: "gpt-4o-mini",   # model identifier
  temperature: 0.0,        # 0.0 = deterministic
  max_tokens: 1024,        # max completion tokens
  timeout: 30,             # seconds
  schema: {                # optional structured output schema
    type: "array",
    items: {
      type: "object",
      properties: {
        line:    { type: "integer" },
        message: { type: "string"  }
      }
    }
  }
)

prompt_template "Your prompt here. Use {{source}} for the file content."
```

### Overriding `interpret`

The default `interpret` expects `{line:, message:}` keys. Override for different shapes:

```ruby
def interpret(results, context)
  results.each do |result|
    line = result.fetch("line_number", result.fetch("line", 1)).to_i
    msg  = result.fetch("issue", result.fetch("message", "AI detected a problem"))
    node = OpenStruct.new(line: line, column: 0)
    violation(node, msg)
  end
end
```

### Using strategies in Ruby AI checks

```ruby
def check(context)
  filter = Backpressure::AI::Strategies::PreFilter.new(pattern: /MUST|SHOULD|SHALL/)
  return unless filter.should_run?(context.source)

  provider = Backpressure::AI::Provider.for(
    ai_settings[:provider],
    config: Backpressure.configuration.ai_config
  )

  strategy = Backpressure::AI::Strategies::Consensus.new(count: 3)
  results = strategy.evaluate do |_index|
    provider.complete(
      prompt: render_prompt(context.source),
      model: ai_settings[:model],
      temperature: ai_settings[:temperature],
      max_tokens: ai_settings[:max_tokens],
      schema: ai_settings[:schema]
    )
  end

  interpret(results.select { |r| r[:agreed] }, context)
end
```

---

## Format 6: AI Rule (YAML)

The simplest format for AI checks. Write a `.check.yml` file and place it in your `check_paths` directory. No Ruby required.

### Full YAML schema

```yaml
# Required
name: CheckClassName           # becomes the Ruby class name

# Optional metadata
category: ai_quality           # any symbol string
severity: warning              # error | warning | info (default: warning)
files: "lib/prompts/**/*.rb"   # file glob (default: all files)
requires:
  - source                     # source | ast (default: source)

# AI provider configuration
ai:
  provider: openai             # registered provider name
  model: gpt-4o-mini          # model identifier
  temperature: 0.0             # float 0.0–1.0
  max_tokens: 1024             # integer
  timeout: 30                  # seconds

  # Accuracy strategy (optional)
  strategy:
    type: consensus            # consensus | pre_filter
    count: 3                   # (consensus only) number of runs

  # Structured output schema (optional — helps models return valid JSON)
  schema:
    type: array
    items:
      type: object
      properties:
        line:
          type: integer
        message:
          type: string
      required:
        - line
        - message

# Prompt template
# {{source}} is replaced with the file content at runtime
prompt: |
  You are a senior engineer reviewing AI agent prompt files.

  Identify any of the following issues:
  1. Requirements expressed with MUST/SHOULD/SHALL that are ambiguous
  2. Contradictory requirements in the same file
  3. Missing error-handling clauses for agent failure modes

  Return a JSON array of objects with keys "line" (integer) and "message" (string).
  Return [] if there are no issues.

  FILE:
  {{source}}
```

### Pre-filter strategy in YAML

Skip the AI call when the source is unlikely to have violations:

```yaml
ai:
  strategy:
    type: pre_filter
    pattern: "MUST|SHOULD|SHALL"   # regex string
```

### Consensus strategy in YAML

Run the check N times and keep only violations agreed on by the majority:

```yaml
ai:
  strategy:
    type: consensus
    count: 5   # run 5 times; keep violations appearing ≥3 times
```

---

## Recording Violations

Inside `check(context)`, use `violation` to record a finding:

```ruby
violation(
  node_or_struct,          # anything with .line and .column (or .loc.line / .loc.column)
  "Human-readable message explaining what is wrong and what to do instead",
  auto_correctable: false, # default false
  correction: nil          # Correction instance, or nil
)
```

The `message` should:
- State what is wrong (briefly)
- State what to do instead (ideally)
- Avoid implementation details that will rot

Good: `"Use SafeShell.run instead of system()"`
Bad: `"system() called"`

---

## Skipping a Check

Stop processing the current file for this check without recording a violation:

```ruby
def check(context)
  return skip("File is auto-generated") if context.source.include?("# AUTO-GENERATED")
  # ... normal check logic
end
```

The skipped count is reported in the runner result and surfaced in the `pretty` formatter.

---

## Corrections (Auto-Fix)

Attach a correction to a violation to support auto-fixing.

### Replace

Substitute a string on a specific line:

```ruby
Backpressure::Corrections::Replace.new(
  line: node.loc.line,
  original: "Net::HTTP.get",
  replacement: "HttpClient.get"
)
```

### Insert

Insert text before or after a specific line:

```ruby
# Insert a frozen string literal comment before line 1
Backpressure::Corrections::Insert.new(
  line: 1,
  text: "# frozen_string_literal: true\n",
  position: :before
)

# Insert a blank line after line 5
Backpressure::Corrections::Insert.new(
  line: 5,
  text: "\n",
  position: :after
)
```

### Remove

Delete an entire line:

```ruby
Backpressure::Corrections::Remove.new(line: 23)
```

### Composing multiple corrections

For a violation that requires multiple changes, create a custom `Correction` subclass:

```ruby
class MultiLineCorrection < Backpressure::Correction
  def apply(source)
    lines = source.lines
    # Make multiple edits working from bottom to top (avoid line shift)
    lines[14] = lines[14].gsub("Net::HTTP.get", "HttpClient.get")
    lines.delete_at(10)  # remove unused require
    lines.join
  end
end
```

---

## Ratchet Configuration per Check

Override the ratchet mode for a specific check:

```ruby
class MyCheck < Backpressure::Check
  ratchet :strict    # default: fail on any new violation
  # or
  ratchet :lenient   # (if supported): count-based tolerance
end
```

Or disable ratcheting for a check entirely via `backpressure.yml`:

```yaml
checks:
  MyCheck:
    enabled: false   # skip this check entirely
```

---

## Configuration Overrides in YAML

Per-check settings can be overridden in `backpressure.yml` without touching check source files:

```yaml
checks:
  NoHardcodedUrls:
    enabled: false               # disable on this project
  NoDirectHttp:
    severity: warning            # downgrade from error to warning
  PromptClarityCheck:
    enabled: true                # ensure it is always on
```

---

## Check Naming Conventions

- Class name ends with `Check`: `NoDirectHttpCheck`, `PromptClarityCheck`
- Category: use a symbol that groups related checks: `:architecture`, `:testing`, `:ai_quality`, `:performance`, `:security`
- File name matches snake_case class name: `NoDirectHttpCheck` → `no_direct_http_check.rb`
- YAML check: name matches `CamelCase`, file name matches `snake_case.check.yml`

---

## Complete Examples by Domain

### Architecture enforcement

Prevent direct database access from controller layer:

```ruby
# checks/no_ar_in_controllers_check.rb
class NoArInControllersCheck < Backpressure::Check
  category :architecture
  severity :error
  files "app/controllers/**/*.rb"
  requires :ast

  AR_METHODS = %i[where find find_by create! update! destroy!].freeze

  def check(context)
    context.ast.each_node(:send) do |node|
      receiver    = node.children[0]
      method_name = node.children[1]

      next unless AR_METHODS.include?(method_name)
      next unless receiver&.type == :const

      violation(
        node,
        "ActiveRecord query '#{method_name}' in controller — move to a service object or repository"
      )
    end
  end
end
```

### Testing invariants

Every public model must have a corresponding spec:

```ruby
# checks/model_spec_coverage_check.rb
class ModelSpecCoverageCheck < Backpressure::Check
  category :testing
  severity :warning
  files "app/models/**/*.rb"
  requires :source

  def check(context)
    return if context.source.match?(/# :nodoc:/)  # skip undocumented internal models

    model_name = File.basename(context.file_path, ".rb")
    spec_path  = "spec/models/#{model_name}_spec.rb"

    return if File.exist?(spec_path)

    violation(
      OpenStruct.new(line: 1, column: 0),
      "Model #{model_name} has no spec at #{spec_path}"
    )
  end
end
```

### Component tree rules

Ensure view components only reference lower-level components (molecules use only atoms; organisms use molecules and atoms — not other organisms):

```ruby
# checks/component_hierarchy_check.rb
class ComponentHierarchyCheck < Backpressure::Check
  category :design_system
  severity :error
  files "app/components/**/*.rb"
  requires :ast

  HIERARCHY = { atom: 0, molecule: 1, organism: 2 }.freeze

  def check(context)
    level = detect_level(context.file_path)
    return unless level

    context.ast.each_node(:const) do |node|
      referenced = node.children.last.to_s
      referenced_level = detect_level_by_name(referenced)
      next unless referenced_level

      if HIERARCHY[referenced_level] >= HIERARCHY[level]
        violation(
          node,
          "#{level.capitalize} component references #{referenced} which is at the same or higher level (#{referenced_level})"
        )
      end
    end
  end

  private

  def detect_level(path)
    HIERARCHY.keys.find { |k| path.include?("/#{k}s/") || path.include?("/#{k}/") }
  end

  def detect_level_by_name(name)
    HIERARCHY.keys.find { |k| name.downcase.include?(k.to_s) }
  end
end
```

### AI prompt quality

Detect prompt templates that are missing error-handling instructions:

```yaml
# checks/prompt_error_handling.check.yml
name: PromptErrorHandlingCheck
category: ai_quality
severity: warning
files: "lib/prompts/**/*.rb"

ai:
  provider: openai
  model: gpt-4o-mini
  temperature: 0.0
  max_tokens: 512
  strategy:
    type: pre_filter
    pattern: "PROMPT|prompt|<<~"

prompt: |
  Review the following Ruby file containing AI prompt definitions.
  Identify prompt strings that lack instructions for how the AI should handle:
  1. Missing required input data
  2. Ambiguous or contradictory instructions
  3. What to return when no answer is found

  Return JSON: [{"line": <integer>, "message": "<description>"}]
  Return [] if no issues.

  FILE:
  {{source}}
```

### API design

Ensure all API controllers return consistent JSON error shapes:

```ruby
# checks/api_error_shape_check.rb
class ApiErrorShapeCheck < Backpressure::Check
  category :api_consistency
  severity :error
  files "app/controllers/api/**/*.rb"
  requires :ast

  def check(context)
    context.ast.each_node(:send) do |node|
      method_name = node.children[1]
      next unless method_name == :render

      args = node.children[2..]
      hash_node = args.find { |a| a.type == :hash }
      next unless hash_node

      json_key = hash_node.children.find do |pair|
        pair.children[0].children.last.to_s == "json"
      end
      next unless json_key

      json_value = json_key.children[1]
      next unless json_value.type == :hash

      error_keys = json_value.children.map { |p| p.children[0].children.last.to_s }

      if error_keys.include?("error") && !error_keys.include?("code")
        violation(
          node,
          "API error response must include both 'error' and 'code' keys"
        )
      end
    end
  end
end
```
