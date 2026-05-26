# Backpressure — Generic Extensible Ruby Backpressure Gem

**Date:** 2026-05-25
**Status:** Design approved, pending implementation plan

## Overview

Backpressure is a standalone Ruby gem that provides a unified framework for applying quality backpressure to Ruby codebases. It subsumes RuboCop-style per-node analysis, phlex-lint-style component-tree analysis, and AI prompt-based analysis under a single check-authoring DSL with shared infrastructure for caching, ratcheting, auto-fix, and reporting.

## Goals

- **Unified DSL** — one check-authoring format for deterministic, component-tree, and AI checks
- **Hybrid authoring** — Ruby DSL for deterministic checks, YAML/Markdown for AI checks (low barrier for non-developers)
- **High accuracy with cheap agents** — composable strategies: pre-filter, structured output, consensus voting, escalation chains
- **Ratcheting from day one** — baseline snapshots so checks are adoptable against existing codebases
- **Auto-fix** — deterministic corrections auto-apply; AI suggestions require explicit `--ai-fix` opt-in
- **Pluggable** — new context types, checks, formatters, and indexers via plugin interface
- **Optional RuboCop compilation** — per-node checks can compile to RuboCop cops for editor integration

## Non-Goals

- LSP/editor integration (beyond RuboCop compilation)
- Replacing RuboCop or phlex-lint entirely — existing checks run via adapters
- Auto-applying AI patches without explicit opt-in

---

## Core Abstraction: The Check

Every check implements `Backpressure::Check` — modeled on phlex-lint's `Rule` class.

```ruby
class NoDirectAR < Backpressure::Check
  category "Architecture"
  severity :warning                    # :error, :warning, :info
  files "app/controllers/**/*.rb"
  requires :ast                        # context type(s) needed

  def check(context)
    context.ast.each_node(:send) do |node|
      next unless AR_METHODS.include?(node.method_name)
      violation(node, "Use a service object instead of direct ActiveRecord")
    end
  end

  def auto_correct(node, message)
    Backpressure::Correction::Replace.new(
      node: node,
      replacement: "#{service_name(node)}.call(#{node.arguments.map(&:source).join(', ')})"
    )
  end
end
```

### Class-Level DSL

| Method | Purpose |
|--------|---------|
| `category` | Grouping for filtering and config (e.g., `"AI/Prompts"`, `"Architecture"`) |
| `severity` | `:error`, `:warning`, `:info` |
| `files` | Glob pattern limiting which files the check applies to |
| `requires` | Context types needed: `:ast`, `:tree`, `:source`, `:group`, `:project` (combinable) |
| `ratchet` | `:strict` (default), `:advisory`, or `false` |
| `compilable` | Opt-in to RuboCop compilation |

### Instance Methods

| Method | Purpose |
|--------|---------|
| `check(context)` | Main analysis — call `violation()` for each finding |
| `auto_correct(node, message)` | Return a `Correction` object (optional) |
| `skip(reason)` | Skip the check for this file/group with a reason |

---

## Context Types

Checks declare what input they need via `requires`. Multiple contexts can be combined.

| Context | Scope | Backed By | Use Case |
|---------|-------|-----------|----------|
| `:ast` | per-file | `RuboCop::AST::Node` | Per-node checks (like RuboCop cops) |
| `:tree` | per-file | `Backpressure::ComponentNode` tree (inspired by phlex-lint's `PhlexNode`) | Component composition checks |
| `:source` | per-file | Raw string | Regex patterns, AI prompt checks |
| `:group` | related files | Defined set of companion files | Agent/prompt pairs, model/factory pairs |
| `:project` | cross-file | Indexed AST across all files | Whole-project invariants, cross-artifact |

### Group Context

Groups define relationships between files. The runner assembles each group before invoking the check.

```ruby
class AgentPromptConsistency < Backpressure::Check
  category "AI/Consistency"
  severity :error

  file_group do |path|
    if path.match?(%r{app/ai/agents/(.+)\.rb})
      role :agent, path
      role :prompt, "app/ai/prompts/#{$1}.rb"
    end
  end

  requires :ast, :group

  def check(context)
    agent = context.group["agent"]
    prompt = context.group["prompt"]
    return skip("Prompt file missing") unless prompt

    agent_tools = agent.ast.each_node(:send).select { |n| n.method_name == :tool }
    prompt_refs = prompt.source.scan(/\{\{(\w+)\}\}/).flatten

    agent_tools.each do |tool_node|
      unless prompt_refs.include?(tool_node.first_argument.value.to_s)
        violation(tool_node, "Tool '#{tool_node.first_argument.value}' not referenced in prompt")
      end
    end
  end
end
```

### Project Context

Built once per run, shared across all checks that `requires :project`.

```ruby
class NoOrphanedServices < Backpressure::Check
  category "Architecture"
  files "app/services/**/*.rb"
  requires :project

  def check(context)
    service_classes = context.project.classes_in("app/services/")
    controller_refs = context.project.references_to(service_classes)

    service_classes.each do |klass|
      unless controller_refs.any? { |ref| ref.target == klass }
        violation(klass.node, "Service #{klass.name} is never called")
      end
    end
  end
end
```

The project index is pluggable — custom indexers can register additional artifact types via plugins so cross-artifact checks work naturally.

---

## AI Check Authoring

### YAML Format (low barrier)

```yaml
name: PromptConstraintClarity
category: AI/Prompts
files: "app/ai/prompts/**/*.rb"
requires: source
severity: warning

ai:
  provider: gemini
  model: cheap                         # tier alias resolved from config
  temperature: 0.1
  max_tokens: 1024
  timeout: 30

  strategy:
    pre_filter: "MUST|SHOULD|MAY"
    consensus: 3
    confidence_threshold: 0.8
    escalation:
      - model: cheap
        confidence_threshold: 0.9
      - model: standard
        confidence_threshold: 0.7
      - model: strong

  schema:
    type: array
    items:
      properties:
        line: { type: integer }
        message: { type: string }
        confidence: { type: number }
        suggestion: { type: string }

prompt: |
  Review this prompt class. Are the RFC 2119 constraints
  (MUST, SHOULD, MAY) unambiguous and testable?
  Return violations as JSON array.
```

### Ruby DSL Format (full control)

```ruby
class PromptConstraintClarity < Backpressure::Check
  category "AI/Prompts"
  files "app/ai/prompts/**/*.rb"
  requires :source

  ai do
    provider :gemini
    model :cheap
    temperature 0.1
    pre_filter /MUST|SHOULD|MAY/
    consensus 3
    escalation [:cheap, :standard, :strong]
  end

  prompt <<~PROMPT
    Review this prompt class. Are the RFC 2119 constraints
    (MUST, SHOULD, MAY) unambiguous and testable?
  PROMPT

  def interpret(results, context)
    results.each do |r|
      violation(context.line(r[:line]), r[:message])
    end
  end
end
```

### AI Configuration

**Model tier aliases** — check authors pick tiers, project config maps to models:

```yaml
# backpressure.yml
ai:
  default_provider: gemini
  tiers:
    cheap: gemini-2.0-flash
    standard: gemini-2.5-pro
    strong: claude-sonnet-4-6
  api_keys:
    gemini: ENV[GEMINI_API_KEY]
    openai: ENV[OPENAI_API_KEY]
```

### Composable Accuracy Strategies

| Strategy | Purpose |
|----------|---------|
| `pre_filter` | Regex — only send files matching the pattern to the LLM |
| `consensus` | Run N times, report only majority-agreed violations |
| `confidence_threshold` | Discard LLM results below this confidence score |
| `escalation` | Chain of models — try cheap first, escalate on low confidence |
| `schema` | Constrain LLM output to a strict JSON schema |

Strategies are composable — use any combination per check.

---

## Ratcheting

Baseline snapshots make checks adoptable against existing codebases. CI only fails on new violations.

### Workflow

```bash
# Generate baseline
backpressure check --update-baseline
# → creates backpressure_baseline.yml (committed to repo)

# CI: fail only on new violations
backpressure check
# → exits 0 if violations <= baseline
# → exits 1 if any NEW violations

# After fixing: ratchet down
backpressure check --update-baseline
# → baseline shrinks, locking in improvement
```

### Baseline Format

```yaml
# backpressure_baseline.yml
generated_at: 2026-05-25T17:30:00Z
checks:
  NoDirectAR:
    count: 12
    files:
      - app/controllers/prospects_controller.rb:45
      - app/controllers/accounts_controller.rb:23
  PromptConstraintClarity:
    count: 3
    files:
      - app/ai/prompts/intelligence/job_posting_analyzer.rb:0
```

### Anti-Tamper

- `backpressure check` fails if baseline counts were manually increased
- Baseline can only grow via `--update-baseline`
- `--update-baseline` verifies all listed violations actually exist

### Per-Check Modes

```ruby
ratchet :strict    # default — new violations fail CI
ratchet :advisory  # report but don't fail
ratchet false      # no ratcheting, always report all
```

---

## Caching

Content-hash caching avoids redundant LLM calls on unchanged code.

### Cache Key

```
hash(check_version + prompt_version + file_content_hash + strategy_config)
```

### Storage

```
.backpressure_cache/
  NoDirectAR/
    a3f4b2c1.json
  PromptConstraintClarity/
    e7d8f9a0.json
```

- `.backpressure_cache/` is gitignored — local only
- CI systems use their native build cache to persist between runs
- `backpressure check --no-cache` bypasses
- `backpressure cache clear` wipes

### What Gets Cached

| Check Type | Cached? | Notes |
|------------|---------|-------|
| Deterministic (AST/tree) | Optional | Fast enough without, helps on large projects |
| AI (single call) | Always | Avoids redundant LLM calls |
| AI (consensus) | Per-call | Each vote cached independently |
| Cross-file/project | Invalidates when any input file changes | Conservative for correctness |

### Automatic Invalidation

- Check class body hash changes → all results for that check invalidated
- Prompt text changes → invalidated
- AI tier config changes (e.g., swapping `cheap` model) → invalidated

---

## Auto-Fix

Three tiers of correction with AI fixes gated behind explicit opt-in.

### Deterministic Corrections

Same model as phlex-lint — `auto_correct` returns a `Correction` object:

```ruby
def auto_correct(node, message)
  Backpressure::Correction::Replace.new(
    node: node,
    replacement: "#{service_name(node)}.call(...)"
  )
end
```

### AI Suggestions

The LLM proposes a fix via the `suggestion` field in the output schema. AI checks can use a different (better) model for fix generation:

```yaml
ai:
  model: cheap
  fix_model: standard
```

### CLI Behavior

```bash
backpressure fix                       # deterministic fixes only (safe)
backpressure fix --dry-run             # show what would change
backpressure fix --ai-fix              # include AI suggestions
backpressure fix --ai-fix --interactive  # show diff, confirm per fix
```

### Shipped Correction Types

| Correction | Description |
|------------|-------------|
| `Replace` | Replace a node's source |
| `Insert` | Insert text before/after a node |
| `Remove` | Delete a node |
| `Wrap` | Wrap a node in a method call or block |
| `AddKwarg` | Add a keyword argument |
| `AiSuggestion` | LLM-generated patch — only applied with `--ai-fix` |

### Safety

- Deterministic corrections applied bottom-up (line numbers don't shift)
- AI suggestions never applied without `--ai-fix`
- `--interactive` shows a diff per fix, waits for y/n

---

## CLI

```bash
# Run checks
backpressure check                          # all checks
backpressure check --only NoDirectAR        # specific check
backpressure check --only AI/Prompts        # whole category
backpressure check app/controllers/         # filter by path
backpressure check --format json            # machine-readable
backpressure check --format rubocop         # RuboCop-compatible JSON

# Auto-fix
backpressure fix                            # deterministic only
backpressure fix --ai-fix --interactive     # AI with review

# Ratcheting
backpressure check --update-baseline

# Cache
backpressure cache clear
backpressure cache stats

# Discovery
backpressure list                           # all registered checks
backpressure list --format table            # with metadata
backpressure init                           # generate backpressure.yml scaffold

# RuboCop compilation
backpressure compile --rubocop
```

---

## Configuration

### `backpressure.yml`

```yaml
check_paths:
  - checks/
  - ai_checks/

include:
  - "app/**/*.rb"
  - "lib/**/*.rb"
exclude:
  - "vendor/**"
  - "db/migrate/**"

ai:
  default_provider: gemini
  tiers:
    cheap: gemini-2.0-flash
    standard: gemini-2.5-pro
    strong: claude-sonnet-4-6
  api_keys:
    gemini: ENV[GEMINI_API_KEY]

checks:
  NoDirectAR:
    enabled: true
    severity: error
    exclude:
      - "app/controllers/legacy/**"
  AI/Prompts:
    enabled: true
    severity: warning
  PromptConstraintClarity:
    enabled: false

ratchet:
  baseline_file: backpressure_baseline.yml
  anti_tamper: true

cache:
  enabled: true
  dir: .backpressure_cache

format: pretty

plugins:
  - my_checks
  - ./lib/backpressure_extensions
```

### Resolution Order (most specific wins)

1. Global `include`/`exclude`
2. Category-level (`AI/Prompts`) settings
3. Individual check (`PromptConstraintClarity`) settings
4. Inline skip annotations: `# backpressure:disable CheckName`

---

## Plugin System

```ruby
Backpressure.register_plugin "my_checks" do
  context :graphql_schema do |files|
    GraphQLParser.parse(files)
  end

  checks_from "lib/my_checks/checks/"

  formatter :junit, MyChecks::JunitFormatter
end
```

A plugin can contribute:
- **Context types** — new `requires` options (`:graphql_schema`, `:erb_template`, etc.)
- **Checks** — Ruby classes or YAML files
- **Formatters** — custom output formats
- **Indexers** — extend the project index with new artifact types

### Loading

```yaml
# backpressure.yml
plugins:
  - my_checks          # gem name
  - ./lib/extensions   # local path
```

---

## RuboCop Compilation

Per-node deterministic checks can opt into compilation to real RuboCop cops:

```ruby
class NoDirectAR < Backpressure::Check
  requires :ast
  compilable

  def check(context)
    # ...
  end
end
```

```bash
backpressure compile --rubocop
# → lib/rubocop/cop/backpressure/no_direct_ar.rb
# → .rubocop_backpressure.yml
```

### Constraints

- Only checks with `requires :ast` and no `:project`/`:group` dependency
- AI checks never compile
- Compilation is a build step — regenerate when checks change

### Benefits

- LSP squiggles in editor
- `# rubocop:disable Backpressure/NoDirectAR` works
- Same logic, authored once, runs in both tools

---

## Gem Structure

```
backpressure/
  backpressure.gemspec
  bin/
    backpressure
  lib/
    backpressure.rb
    backpressure/
      version.rb
      cli.rb
      configuration.rb
      check.rb
      ai_check.rb
      yaml_loader.rb
      violation.rb
      contexts/
        ast_context.rb
        tree_context.rb
        source_context.rb
        group_context.rb
        project_context.rb
      project_index.rb
      indexers/
        base.rb
        ruby_indexer.rb
      ai/
        provider.rb
        providers/
          gemini.rb
          openai.rb
          anthropic.rb
          ollama.rb
        strategy.rb
        strategies/
          pre_filter.rb
          consensus.rb
          escalation.rb
          confidence_threshold.rb
        schema_validator.rb
      corrections/
        replace.rb
        insert.rb
        remove.rb
        wrap.rb
        add_kwarg.rb
        ai_suggestion.rb
      ratchet.rb
      baseline.rb
      cache.rb
      runner.rb
      check_registry.rb
      formatters/
        pretty.rb
        json.rb
        rubocop_json.rb
      compiler/
        rubocop_compiler.rb
      plugin.rb
  spec/
```

### Dependencies

| Gem | Required | Purpose |
|-----|----------|---------|
| `rubocop-ast` | Yes | AST parsing |
| `parser` | Yes (transitive) | Ruby parser |
| LLM provider gems | On demand | Loaded only when configured |

The gem works purely deterministic with zero AI dependencies if no AI checks are configured.
