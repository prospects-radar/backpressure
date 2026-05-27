# Backpressure Checks — Design Spec

**Date:** 2026-05-26
**Status:** Approved
**Scope:** 55 checks across 11 categories + 2 framework changes
**Goal:** Replace phlex-lint — backpressure subsumes all component tree analysis

## Framework Change 1: ProjectIndex Context Support

Runner extended to build `ProjectIndex` once at run start, injected via `context.project_index` for checks requiring `:project`.

**Context resolution order (implemented):**
- `[:source]` → `SourceContext`
- `[:ast]` → `AstContext`
- `[:phlex]` → `PhlexContext` (builds PhlexNode tree via `Backpressure::Phlex::Parser`)
- `[:project]` → any context + `project_index` accessor injected
- Combinable: `requires :phlex, :project` gives PhlexContext with project_index

## Framework Change 2: PhlexContext (phlex-lint replacement)

Phlex-lint's `Parser` and `PhlexNode` copied into `Backpressure::Phlex` namespace. New `PhlexContext` wraps the parser and exposes:
- `tree` — PhlexNode root (`:__root__` with children)
- `parser` — Parser instance (skip annotations, `RAW_HTML_ELEMENTS`)
- `source`, `lines`, `line(n)` — raw source access
- `raw_html_elements` — shortcut to `Parser::RAW_HTML_ELEMENTS`

Files added:
- `lib/backpressure/phlex/phlex_node.rb`
- `lib/backpressure/phlex/parser.rb`
- `lib/backpressure/contexts/phlex_context.rb`

Checks using `requires :phlex` get the component tree for free. This replaces phlex-lint for all DesignSystem checks that benefit from semantic tree analysis.

## Check Format Decision

- **YAML `.check.yml`** — pure AI checks that only need `{{source}}` and optionally `{{file_path}}`
- **Ruby classes** — everything else (AST, Phlex, ProjectIndex, hybrid)

## Check Catalog

### Category: DesignSystem (11 checks)

| # | Check | Mode | Ratchet | Description |
|---|-------|------|---------|-------------|
| 1 | `ComponentCatalogEnforcement` | Phlex + ProjectIndex | no | Scans `atoms/`+`molecules/` to build dynamic HTML→component map. Walks PhlexNode tree to flag raw HTML when component exists. Violation includes specific replacement. |
| 2 | `AIInventedPatterns` | AI (YAML) | yes | AI analyzes source for novel raw HTML patterns not caught by catalog. Uses `{{available_atoms}}` and `{{available_molecules}}` populated from ProjectIndex. |
| 3 | `RawHTMLRatchet` | Source | strict | Counts raw HTML element calls in GlassMorph files. Ratchets: baseline count must not increase. |
| 4 | `NewFileDesignSystemCompliance` | Source + baseline | no | Files not in baseline must have zero raw HTML. Gate check for new code. |
| 5 | `OrphanedComponent` | ProjectIndex | no | Component in `atoms/`/`molecules/`/`organisms/` never rendered from any view or parent component. |
| 6 | `InconsistentComponentUsage` | Phlex + ProjectIndex | no | Walks PhlexNode trees across all views. Flags outlier kwarg patterns (e.g., Button with `:secondary` in 2 files but `:primary` in 90). |
| 7 | `ComponentCoverageDrift` | Phlex + ProjectIndex | strict | Walks PhlexNode trees. Measures % design system components vs raw HTML nodes. Coverage must not decrease. |
| 8 | `UnusedComponentSlots` | Phlex + ProjectIndex | no | PhlexNode tree shows yield blocks in component def. ProjectIndex checks no caller passes a block. |
| 9 | `ViewComplexity` | Phlex | no | Counts PhlexNode tree nodes. Views with >15 component calls flagged. Configurable threshold. |
| 10 | `DuplicateComponentPatterns` | Phlex + ProjectIndex | no | Compares PhlexNode tree structures across files. Near-identical trees → extract shared organism. |
| 11 | `MissingTestId` | ProjectIndex | no | Organisms without `tid()` that ARE referenced in Cucumber steps. |

### Category: Architecture (3 checks)

| # | Check | Mode | Ratchet | Description |
|---|-------|------|---------|-------------|
| 12 | `CircularServiceDependency` | ProjectIndex | no | Detects A→B→A service call cycles. Builds dependency graph from `ServiceClass.new` / `.run` calls. |
| 13 | `OrphanedService` | ProjectIndex | no | Service class in `app/services/` never referenced from any controller or other service. |
| 14 | `ServiceFanOut` | ProjectIndex | no | Service calls >5 other services. Configurable threshold. |

### Category: AI / Prompt Safety (5 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 15 | `PromptInjectionSurface` | AI | YAML | System prompt structure allows user input to override instructions. |
| 16 | `PIIInSystemPrompt` | AI | YAML | Hardcoded names, emails, API keys, internal URLs in prompt templates. |
| 17 | `PromptLeakageRisk` | AI | YAML | Prompt reveals internal tool names, schemas, or system architecture. |
| 18 | `NoInputSanitization` | AST + ProjectIndex | Ruby | Agent's `def user` interpolates data with zero sanitization in call chain. |
| 19 | `SystemPromptDrift` | AI + ProjectIndex | Ruby | Two agents share near-identical system prompts. Extract shared base. |

### Category: AI / Output Safety (5 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 20 | `UnvalidatedOutput` | AST + ProjectIndex | Ruby | Agent result used in controller/view without `.success?` or schema check. |
| 21 | `OutputToSQL` | AST + ProjectIndex | Ruby | Agent output flows into ActiveRecord query — SQL injection via LLM. |
| 22 | `OutputToHTML` | AST + ProjectIndex | Ruby | Agent output rendered in view without `sanitize` — XSS via LLM. |
| 23 | `HallucinationGuardMissing` | AI | YAML | Agent returns IDs/URLs/entity refs but no validation they exist. |
| 24 | `SchemaFieldCoverage` | AI | YAML | Schema declares fields prompt never mentions (or vice versa). |

### Category: AI / Cost & Resource (5 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 25 | `NoMaxTokensLimit` | AST | Ruby | AI call has no `max_tokens` — unbounded cost. |
| 26 | `ExpensiveModelForSimpleTask` | AI | YAML | Large model for task achievable with small model (classification, yes/no). |
| 27 | `UnboundedRetryLoop` | AST | Ruby | Agent retries on failure with no max attempt cap. |
| 28 | `MissingCacheability` | AST + AI | Ruby | Deterministic prompt called repeatedly but not cached. |
| 29 | `LargeContextWindow` | AST | Ruby | Agent stuffs >50KB into prompt without summarization. |

### Category: AI / Observability (4 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 30 | `NoLogging` | AST | Ruby | Agent overrides or skips `RAAF.logger`. |
| 31 | `NoTraceId` | AST + ProjectIndex | Ruby | AI call chain has no correlation ID. |
| 32 | `SilentFailure` | AST | Ruby | Agent rescues errors, returns default instead of logging + surfacing. |
| 33 | `AuditTrailMissing` | ProjectIndex | Ruby | Agent modifies DB records but call is not logged to audit table. |

### Category: AI / Tool & Scope Safety (4 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 34 | `OverprivilegedToolSet` | AI + ProjectIndex | Ruby | Agent has write/delete tools but task only requires read. |
| 35 | `ToolWithoutConfirmation` | AST + ProjectIndex | Ruby | Destructive tool has no human-in-the-loop gate. |
| 36 | `UnboundedToolExecution` | AST | Ruby | Tool execution has no timeout. |
| 37 | `ToolChainDepth` | AST + ProjectIndex | Ruby | Pipeline >5 sequential agent hops. |

### Category: AI / Data Governance (3 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 38 | `SensitiveDataInPrompt` | AI + ProjectIndex | Ruby | Model PII fields loaded into prompt without field filtering. |
| 39 | `CrossTenantDataLeak` | ProjectIndex | Ruby | Agent receives records without tenant scoping. |
| 40 | `ExternalAPIKeyExposure` | AST | Ruby | Prompt or tool passes API keys that could leak. |

### Category: AI / Human Oversight (3 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 41 | `AutonomousStateChange` | AST + ProjectIndex | Ruby | Agent changes record state without human approval step. |
| 42 | `NoFallbackPath` | AST | Ruby | Agent failure has no fallback — raw error or nothing. |
| 43 | `UserFacingWithoutReview` | ProjectIndex | Ruby | Agent output displayed to end user without moderation. |

### Category: AI / Testing (4 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 44 | `AgentWithoutSpec` | ProjectIndex | Ruby | Agent in `app/ai/agents/` has no `_spec.rb`. |
| 45 | `PromptWithoutTest` | ProjectIndex | Ruby | Prompt class in `app/ai/prompts/` has no spec. |
| 46 | `NoEdgeCaseTests` | AI | YAML | Spec tests only happy path — no malformed output / timeout / refusal tests. |
| 47 | `DeterminismUntested` | AST | Ruby | Agent with `temperature: 0` but spec doesn't assert deterministic output. |

### Category: RAAF (3 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 48 | `PromptClarity` | AI | YAML | Vague or ambiguous system prompt that could confuse LLM. |
| 49 | `SchemaPromptMismatch` | AI | YAML | Schema declares fields prompt never asks for (or vice versa). |
| 50 | `ToolDescriptionQuality` | AI | YAML | Tool descriptions too terse for LLM to select correctly. |

### Category: MultiTenancy (1 check)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 51 | `UnscopedCrossFileQuery` | ProjectIndex | Ruby | Service queries model lacking `acts_as_tenant` — catches at call site. |

### Category: Testing (1 check)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 52 | `FactoryWithoutSpec` | ProjectIndex | Ruby | Factory defined but never referenced in any spec. |

### Category: Hygiene (2 checks)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 53 | `TodoTracker` | Source | Ruby | `TODO`/`FIXME`/`HACK` comments. Ratchet: count must not increase. |
| 54 | `DeadRequire` | ProjectIndex | Ruby | `require`/`require_relative` of files that don't exist. |

### Category: Convention (1 check)

| # | Check | Mode | Format | Description |
|---|-------|------|--------|-------------|
| 55 | `CommentedOutCode` | AI | YAML | Distinguishes real comments from dead commented-out code. |

## File Organization

```
lib/backpressure/checks/
├── design_system/
│   ├── component_catalog_enforcement.rb
│   ├── raw_html_ratchet.rb
│   ├── new_file_design_system_compliance.rb
│   ├── orphaned_component.rb
│   ├── inconsistent_component_usage.rb
│   ├── component_coverage_drift.rb
│   ├── unused_component_slots.rb
│   ├── view_complexity.rb
│   ├── duplicate_component_patterns.rb
│   └── missing_test_id.rb
├── architecture/
│   ├── circular_service_dependency.rb
│   ├── orphaned_service.rb
│   └── service_fan_out.rb
├── ai/
│   ├── prompt_safety/
│   │   ├── no_input_sanitization.rb
│   │   └── system_prompt_drift.rb
│   ├── output_safety/
│   │   ├── unvalidated_output.rb
│   │   ├── output_to_sql.rb
│   │   └── output_to_html.rb
│   ├── cost/
│   │   ├── no_max_tokens_limit.rb
│   │   ├── unbounded_retry_loop.rb
│   │   ├── missing_cacheability.rb
│   │   └── large_context_window.rb
│   ├── observability/
│   │   ├── no_logging.rb
│   │   ├── no_trace_id.rb
│   │   ├── silent_failure.rb
│   │   └── audit_trail_missing.rb
│   ├── tool_safety/
│   │   ├── overprivileged_tool_set.rb
│   │   ├── tool_without_confirmation.rb
│   │   ├── unbounded_tool_execution.rb
│   │   └── tool_chain_depth.rb
│   ├── data_governance/
│   │   ├── sensitive_data_in_prompt.rb
│   │   ├── cross_tenant_data_leak.rb
│   │   └── external_api_key_exposure.rb
│   ├── human_oversight/
│   │   ├── autonomous_state_change.rb
│   │   ├── no_fallback_path.rb
│   │   └── user_facing_without_review.rb
│   └── testing/
│       ├── agent_without_spec.rb
│       ├── prompt_without_test.rb
│       └── determinism_untested.rb
├── raaf/
│   (empty — all RAAF checks are YAML)
├── multi_tenancy/
│   └── unscoped_cross_file_query.rb
├── testing/
│   └── factory_without_spec.rb
├── hygiene/
│   ├── todo_tracker.rb
│   └── dead_require.rb
└── convention/
    (empty — CommentedOutCode is YAML)

checks/yaml/
├── ai/
│   ├── prompt_injection_surface.check.yml
│   ├── pii_in_system_prompt.check.yml
│   ├── prompt_leakage_risk.check.yml
│   ├── hallucination_guard_missing.check.yml
│   ├── schema_field_coverage.check.yml
│   ├── expensive_model_for_simple_task.check.yml
│   └── no_edge_case_tests.check.yml
├── raaf/
│   ├── prompt_clarity.check.yml
│   ├── schema_prompt_mismatch.check.yml
│   └── tool_description_quality.check.yml
├── design_system/
│   └── ai_invented_patterns.check.yml
└── convention/
    └── commented_out_code.check.yml

spec/backpressure/checks/
├── design_system/
│   ├── component_catalog_enforcement_spec.rb
│   ├── raw_html_ratchet_spec.rb
│   ... (one spec per check)
├── architecture/
├── ai/
│   ├── prompt_safety/
│   ├── output_safety/
│   ├── cost/
│   ├── observability/
│   ├── tool_safety/
│   ├── data_governance/
│   ├── human_oversight/
│   └── testing/
├── raaf/
├── multi_tenancy/
├── testing/
├── hygiene/
└── convention/
```

## Summary

- **43 Ruby checks** + **12 YAML checks** = **55 checks total**
- **1 framework change** (Runner + ProjectContext)
- **55 RSpec files**
- Files scoped to `app/ai/`, `app/services/`, `app/components/glass_morph/`, `app/views/glass_morph/` as appropriate
