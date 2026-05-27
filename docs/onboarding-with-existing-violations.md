# Onboarding Backpressure With Existing Violations

When you introduce Backpressure into an existing codebase, you will almost certainly have a large number of pre-existing violations. This guide covers three proven workflows for handling that situation, depending on your priorities and team size.

---

## Background: The Ratchet System

All three workflows rely on Backpressure's built-in ratchet (baseline) system.

- `--update-baseline` snapshots current violations to `backpressure_baseline.yml`
- CI compares live violations against that baseline — only **new** violations fail the build
- `anti_tamper: true` detects if the baseline was manually inflated, preventing abuse
- As violations are fixed, update the baseline to reflect the lower count — the ratchet only moves down

```yaml
# backpressure.yml
ratchet:
  baseline_file: backpressure_baseline.yml
  anti_tamper: true
```

---

## Workflow A — Baseline Everything, Ratchet Down by Category

**Best for:** teams that need CI green immediately and want a low-friction start.

### When to use

- Violations across many categories, no immediate capacity to triage
- Team is mid-sprint and cannot absorb disruption
- Want to establish the tooling first, fix debt on a parallel track

### Steps

**Step 1: Snapshot all violations**

```bash
bundle exec backpressure check --update-baseline
git add backpressure_baseline.yml
git commit -m "chore: accept existing backpressure violations as baseline"
```

CI is now green. No new violations can be introduced.

**Step 2: Pick one category per sprint**

Each sprint, select one check category (e.g. `design_system`, `testing`, `hygiene`). Fix all violations in that category across the codebase.

**Step 3: Update baseline after each category is clean**

```bash
bundle exec backpressure check --update-baseline
git add backpressure_baseline.yml
git commit -m "fix: resolve all design_system backpressure violations"
```

**Step 4: Lock the category in CI**

Once a category reaches zero violations, remove it from the baseline so it can never regress.

### Trade-offs

| Pro | Con |
|-----|-----|
| CI green within minutes | All violations hidden initially |
| Zero team disruption | Risk of "baseline amnesia" — debt never gets fixed |
| No coordination required | No visibility into severity distribution |

### Preventing baseline amnesia

Track cleanup as explicit sprint items. Add a dashboard check: if baseline counts have not decreased in 4 weeks, escalate in planning.

---

## Workflow B — Triage First, Baseline by Severity

**Best for:** teams that want fast CI unblock but cannot afford to ignore critical violations.

### When to use

- Mix of severity levels across checks (some are security/safety-critical)
- Team has an hour for an initial triage pass
- Want meaningful enforcement from day one, not just "nothing new"

### Steps

**Step 1: Get a structured violation report**

```bash
bundle exec backpressure check --format json > violations.json
```

Group by check name and severity:

```bash
# Count violations per check, sorted
cat violations.json | jq '[.violations[] | {check: .check, severity: .severity}] | group_by(.check) | map({check: .[0].check, severity: .[0].severity, count: length}) | sort_by(-.count)[]'
```

**Step 2: Classify each check**

| Severity | Decision | Examples |
|----------|----------|---------|
| `error` (security, data-safety, AI safety) | Fix now — do NOT baseline | `multi_tenancy/*`, `ai/data_governance/*`, `ai/output_safety/*` |
| `error` (structural/quality) | Fix within 1 sprint — baseline temporarily | `architecture/circular_service_dependency` |
| `warning` | Baseline — fix on cadence | `design_system/*`, `testing/*` |
| `info` | Baseline — fix opportunistically | `hygiene/*` |

**Step 3: Baseline only non-critical violations**

Disable critical checks temporarily while you fix them, then re-enable:

```yaml
# backpressure.yml — while fixing critical violations
checks:
  MultiTenancy/CrossTenantQuery:
    enabled: false   # fixing this week — do not baseline
```

Baseline everything else:

```bash
bundle exec backpressure check --update-baseline
git add backpressure_baseline.yml
git commit -m "chore: baseline non-critical backpressure violations"
```

Re-enable critical checks once fixed:

```bash
# Remove the 'enabled: false' lines, then:
bundle exec backpressure check --update-baseline
git add backpressure_baseline.yml
git commit -m "fix: resolve critical multi-tenancy violations"
```

**Step 4: Ratchet down on cadence**

Same as Workflow A step 2–4: pick a category per sprint, fix, update baseline.

### Trade-offs

| Pro | Con |
|-----|-----|
| Critical violations get real attention immediately | 1–2 hours upfront triage cost |
| Team never normalizes ignoring security checks | Requires severity classification judgment call |
| Gives visibility into where technical debt lives | Slightly more complex CI setup initially |

---

## Workflow C — Progressive Category Enrollment

**Best for:** large teams where changing CI behavior causes friction; organizations that need gradual adoption.

### When to use

- Many developers, high PR throughput — broad CI change is disruptive
- Team unfamiliar with Backpressure — need time to build habits before enforcement
- Want to treat each check category as its own adoption milestone

### Steps

**Step 1: Install with all checks disabled in CI**

```yaml
# backpressure.yml
checks:
  # All categories start disabled
  design_system:
    enabled: false
  testing:
    enabled: false
  hygiene:
    enabled: false
  architecture:
    enabled: false
  multi_tenancy:
    enabled: false
  ai:
    enabled: false
```

Run in report-only mode initially:

```bash
bundle exec backpressure check --no-fail
```

**Step 2: Enroll one category per sprint**

Each sprint, pick one category. Snapshot its current violations as baseline, then enable it in CI:

```bash
# Example: enrolling the 'hygiene' category
bundle exec backpressure check --update-baseline
```

```yaml
# backpressure.yml — enable hygiene category
checks:
  hygiene:
    enabled: true   # now enforced in CI
```

```bash
git add backpressure.yml backpressure_baseline.yml
git commit -m "chore: enroll hygiene checks in backpressure CI enforcement"
```

**Step 3: Announce to team before each enrollment**

Before enabling a new category:
1. Share the violation count and what the checks enforce
2. Give the team one sprint to fix easy wins voluntarily
3. Enable enforcement the following sprint

**Step 4: Quarterly ratchet review**

Each quarter, review baseline counts per enrolled category. Assign cleanup owners for any category where count has not decreased.

### Recommended enrollment order

| Sprint | Category | Rationale |
|--------|----------|-----------|
| 1 | `hygiene` | Low friction, quick wins |
| 2 | `testing` | Improves confidence for other cleanup |
| 3 | `design_system` | Visual consistency |
| 4 | `architecture` | Structural — needs more careful fixing |
| 5 | `multi_tenancy` | Critical — team needs context first |
| 6 | `ai` | Specialized — AI safety checks |

### Trade-offs

| Pro | Con |
|-----|-----|
| Lowest disruption to shipping teams | Slowest path to full enforcement |
| Team builds habits before enforcement | Critical violations may stay unchecked for months |
| Each category gets focused attention | Requires sustained organizational commitment |

---

## Choosing a Workflow

| Situation | Recommended workflow |
|-----------|---------------------|
| CI red, no time to triage, just need it green | A |
| CI red, have 1–2 hours, want to protect critical checks | B |
| No CI enforcement yet, large team, gradual rollout preferred | C |
| Mix: unblock fast AND protect security checks | B |

Workflows can be combined: use B's severity triage to decide which categories to enroll first in C's sprint cadence.

---

## Shared Best Practices

**Commit baseline changes with context:**

```bash
git commit -m "fix: resolve NoDirectHttp violations in webhook_service

Reduced baseline from 12 to 0 for NoDirectHttp check.
Remaining baseline violations are in external integration files (tracked in #456)."
```

**Never manually edit `backpressure_baseline.yml` to increase counts.** `anti_tamper: true` will detect this and fail CI. If you need to temporarily accept new violations, use `--update-baseline` with a clear commit message explaining why.

**Review baseline drift in PR review.** If a PR increases any baseline count, require justification in the PR description.

**Use `# backpressure:disable` sparingly** — only for one-off exceptions with a comment explaining why, not as a general escape hatch.
