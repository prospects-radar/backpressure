# Backpressure Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 55 backpressure checks (43 Ruby + 12 YAML) across 11 categories with full RSpec coverage.

**Architecture:** Each check is a standalone class inheriting `Backpressure::Check` (or defined as `.check.yml` for pure-AI). Checks use four context types: `:source` (line scanning), `:ast` (rubocop-ast node traversal), `:phlex` (PhlexNode component tree), and `:project` (cross-file via `ProjectIndex`). Framework changes (Runner, PhlexContext, ProjectContext) are already implemented.

**Tech Stack:** Ruby 3.1+, rubocop-ast, parser gem (for Phlex), RSpec

**Base path:** `/Users/hajee/Enterprise Modules Dropbox/Bert Hajee/enterprisemodules/work/prospects_radar/vendor/local_gems/backpressure`

**Test pattern:** All specs use tmpdir with ephemeral files. Check classes are tested by creating source strings, building contexts, running the check, and asserting violations. AI checks use the `:test` provider which returns `[]`.

---

## Task 0: Add `parser` gem dependency

**Files:**
- Modify: `backpressure.gemspec`

- [ ] **Step 1: Add parser dependency**

```ruby
spec.add_dependency "parser", "~> 3.3"
```

Add after the `rubocop-ast` line.

- [ ] **Step 2: Run bundle install**

Run: `bundle install`
Expected: Success

- [ ] **Step 3: Commit**

```bash
git add backpressure.gemspec Gemfile.lock
git commit -m "build: add parser gem dependency for PhlexContext"
```

---

## Task 1: Framework spec updates for new contexts

**Files:**
- Create: `spec/backpressure/contexts/phlex_context_spec.rb`
- Create: `spec/backpressure/phlex/parser_spec.rb`
- Create: `spec/backpressure/phlex/phlex_node_spec.rb`
- Modify: `spec/backpressure/runner_spec.rb`

- [ ] **Step 1: Write PhlexNode spec**

```ruby
# spec/backpressure/phlex/phlex_node_spec.rb
# frozen_string_literal: true

RSpec.describe Backpressure::Phlex::PhlexNode do
  let(:root) { described_class.new(name: :__root__) }

  let(:button) do
    described_class.new(
      name: :Button,
      kwargs: { variant: :primary },
      parent: root,
      children: []
    ).tap { |n| root.children << n }
  end

  let(:icon) do
    described_class.new(
      name: :Icon,
      kwargs: { name: :check },
      parent: button,
      children: []
    ).tap { |n| button.children << n }
  end

  describe "#each_node" do
    it "yields all non-root nodes depth-first" do
      icon # trigger lazy creation
      names = root.each_node.map(&:name)
      expect(names).to eq([:Button, :Icon])
    end

    it "filters by component name" do
      icon
      names = root.each_node(:Icon).map(&:name)
      expect(names).to eq([:Icon])
    end

    it "never yields the root node" do
      expect(root.each_node.to_a).to be_empty
    end
  end

  describe "#ancestor?" do
    it "returns true when ancestor has the given name" do
      expect(icon.ancestor?(:Button)).to be true
    end

    it "returns false when no ancestor matches" do
      expect(button.ancestor?(:Icon)).to be false
    end
  end

  describe "#kwarg" do
    it "returns the value for a keyword argument" do
      expect(button.kwarg(:variant)).to eq(:primary)
    end

    it "returns nil for missing kwargs" do
      expect(button.kwarg(:size)).to be_nil
    end
  end

  describe "#direct_children_named" do
    it "returns only direct children matching the name" do
      icon
      expect(root.direct_children_named(:Button).map(&:name)).to eq([:Button])
      expect(root.direct_children_named(:Icon)).to be_empty
    end
  end
end
```

- [ ] **Step 2: Write Parser spec**

```ruby
# spec/backpressure/phlex/parser_spec.rb
# frozen_string_literal: true

RSpec.describe Backpressure::Phlex::Parser do
  def parse(source)
    described_class.parse_source(source)
  end

  it "parses a simple Phlex component with view_template" do
    tree = parse(<<~RUBY)
      class MyComponent < Phlex::HTML
        def view_template
          div(class: "wrapper") do
            Button(variant: :primary)
          end
        end
      end
    RUBY

    expect(tree).not_to be_nil
    names = tree.each_node.map(&:name)
    expect(names).to include(:div, :Button)
  end

  it "returns nil for files without view_template" do
    tree = parse("class Foo; def bar; end; end")
    expect(tree).to be_nil
  end

  it "extracts kwargs from component calls" do
    tree = parse(<<~RUBY)
      class C < Phlex::HTML
        def view_template
          Button(variant: :primary, size: :lg)
        end
      end
    RUBY

    button = tree.each_node(:Button).first
    expect(button.kwarg(:variant)).to eq(:primary)
    expect(button.kwarg(:size)).to eq(:lg)
  end

  it "expands private helper methods inline" do
    tree = parse(<<~RUBY)
      class C < Phlex::HTML
        def view_template
          render_actions
        end

        private

        def render_actions
          Button(variant: :secondary)
        end
      end
    RUBY

    expect(tree.each_node(:Button).count).to eq(1)
  end

  it "distinguishes raw HTML from components" do
    tree = parse(<<~RUBY)
      class C < Phlex::HTML
        def view_template
          div { span { text "hello" } }
          Button(variant: :primary)
        end
      end
    RUBY

    names = tree.each_node.map(&:name)
    expect(names).to include(:div, :span, :Button)
  end

  it "collects skip annotations" do
    parser = described_class.new(<<~RUBY, "(test)")
      class C < Phlex::HTML
        def view_template
          # backpressure:disable RawHTMLRatchet
          div(class: "legacy")
          # backpressure:enable RawHTMLRatchet
          div(class: "new")
        end
      end
    RUBY
    parser.parse

    expect(parser.disabled_at?(4, "RawHTMLRatchet")).to be true
    expect(parser.disabled_at?(6, "RawHTMLRatchet")).to be false
  end
end
```

- [ ] **Step 3: Write PhlexContext spec**

```ruby
# spec/backpressure/contexts/phlex_context_spec.rb
# frozen_string_literal: true

RSpec.describe Backpressure::Contexts::PhlexContext do
  let(:source) do
    <<~RUBY
      class MyView < Phlex::HTML
        def view_template
          div(class: "wrap") do
            Button(variant: :primary)
          end
        end
      end
    RUBY
  end

  subject(:context) { described_class.new(source: source, file_path: "app/views/test.rb") }

  it "exposes the PhlexNode tree" do
    expect(context.tree).not_to be_nil
    expect(context.tree.each_node.map(&:name)).to include(:div, :Button)
  end

  it "exposes raw source and lines" do
    expect(context.source).to eq(source)
    expect(context.lines).to be_an(Array)
    expect(context.line(1)).to include("class MyView")
  end

  it "exposes raw_html_elements" do
    expect(context.raw_html_elements).to include(:div)
    expect(context.raw_html_elements).not_to include(:Button)
  end

  it "exposes the parser" do
    expect(context.parser).to be_a(Backpressure::Phlex::Parser)
  end
end
```

- [ ] **Step 4: Add Runner spec for :phlex and :project contexts**

Add to `spec/backpressure/runner_spec.rb`:

```ruby
describe "context building" do
  let(:phlex_check) do
    Class.new(Backpressure::Check) do
      files "**/*.rb"
      requires :phlex
      def self.name; "PhlexCheck"; end
      def check(context)
        skip("No tree") unless context.tree
      end
    end
  end

  let(:project_check) do
    Class.new(Backpressure::Check) do
      files "**/*.rb"
      requires :source, :project
      def self.name; "ProjectCheck"; end
      def check(context)
        skip("No index") unless context.respond_to?(:project_index)
      end
    end
  end

  it "builds PhlexContext for checks requiring :phlex" do
    registry = Backpressure::CheckRegistry.new
    registry.register(phlex_check)
    runner = described_class.new(config: config, registry: registry)

    tmpfile = Tempfile.new(["test", ".rb"])
    tmpfile.write("class C < Phlex::HTML; def view_template; div; end; end")
    tmpfile.close

    result = runner.run(files: [tmpfile.path])
    expect(result.skipped).to be_empty
  ensure
    tmpfile.unlink
  end

  it "injects project_index for checks requiring :project" do
    registry = Backpressure::CheckRegistry.new
    registry.register(project_check)
    runner = described_class.new(config: config, registry: registry)

    tmpfile = Tempfile.new(["test", ".rb"])
    tmpfile.write("class Foo; end")
    tmpfile.close

    result = runner.run(files: [tmpfile.path])
    expect(result.skipped).to be_empty
  ensure
    tmpfile.unlink
  end
end
```

- [ ] **Step 5: Run all specs**

Run: `bundle exec rspec`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add spec/backpressure/phlex/ spec/backpressure/contexts/phlex_context_spec.rb spec/backpressure/runner_spec.rb
git commit -m "test: add specs for PhlexContext, Parser, PhlexNode, and Runner context building"
```

---

## Task 2: Hygiene checks (2 checks — simplest, proves the pattern)

**Files:**
- Create: `lib/backpressure/checks/hygiene/todo_tracker.rb`
- Create: `lib/backpressure/checks/hygiene/dead_require.rb`
- Create: `spec/backpressure/checks/hygiene/todo_tracker_spec.rb`
- Create: `spec/backpressure/checks/hygiene/dead_require_spec.rb`

- [ ] **Step 1: Write TodoTracker failing spec**

```ruby
# spec/backpressure/checks/hygiene/todo_tracker_spec.rb
# frozen_string_literal: true

require "backpressure/checks/hygiene/todo_tracker"

RSpec.describe Backpressure::Checks::Hygiene::TodoTracker do
  def run_check(source, file_path: "app/models/user.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags TODO comments" do
    check = run_check("# TODO: fix this\ncode\n# TODO: and this\n")
    expect(check.violations.size).to eq(2)
    expect(check.violations.map(&:line)).to eq([1, 3])
  end

  it "flags FIXME comments" do
    check = run_check("# FIXME: broken\n")
    expect(check.violations.size).to eq(1)
  end

  it "flags HACK comments" do
    check = run_check("# HACK: workaround\n")
    expect(check.violations.size).to eq(1)
  end

  it "ignores normal comments" do
    check = run_check("# This is a normal comment\ncode\n")
    expect(check.violations).to be_empty
  end

  it "is case-insensitive" do
    check = run_check("# todo: lowercase\n")
    expect(check.violations.size).to eq(1)
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("Hygiene")
    expect(described_class.check_severity).to eq(:warning)
    expect(described_class.ratchet_mode).to eq(:strict)
  end
end
```

- [ ] **Step 2: Run spec — verify failure**

Run: `bundle exec rspec spec/backpressure/checks/hygiene/todo_tracker_spec.rb`
Expected: LoadError — file not found

- [ ] **Step 3: Implement TodoTracker**

```ruby
# lib/backpressure/checks/hygiene/todo_tracker.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module Hygiene
      class TodoTracker < Check
        category "Hygiene"
        severity :warning
        files "**/*.rb"
        requires :source
        ratchet :strict

        PATTERN = /\b(TODO|FIXME|HACK)\b/i

        def check(context)
          context.lines.each_with_index do |line, idx|
            next unless line.match?(PATTERN)

            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            match = line.match(PATTERN)
            violation(node, "#{match[1].upcase} comment found — tracked by ratchet")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run spec — verify pass**

Run: `bundle exec rspec spec/backpressure/checks/hygiene/todo_tracker_spec.rb`
Expected: All pass

- [ ] **Step 5: Write DeadRequire failing spec**

```ruby
# spec/backpressure/checks/hygiene/dead_require_spec.rb
# frozen_string_literal: true

require "backpressure/checks/hygiene/dead_require"

RSpec.describe Backpressure::Checks::Hygiene::DeadRequire do
  def run_check(source, file_path:, project_files: [])
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    index = Backpressure::ProjectIndex.new(classes: [], files: project_files)
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    check
  end

  it "flags require_relative pointing to nonexistent file" do
    check = run_check(
      'require_relative "nonexistent"',
      file_path: "/tmp/app/models/user.rb",
      project_files: ["/tmp/app/models/user.rb"]
    )
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("nonexistent")
  end

  it "passes when required file exists" do
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.rb")
      dep = File.join(dir, "helper.rb")
      File.write(main, 'require_relative "helper"')
      File.write(dep, "# helper")

      check = run_check(
        File.read(main),
        file_path: main,
        project_files: [main, dep]
      )
      expect(check.violations).to be_empty
    end
  end

  it "has correct metadata" do
    expect(described_class.check_category).to eq("Hygiene")
    expect(described_class.required_contexts).to include(:project)
  end
end
```

- [ ] **Step 6: Implement DeadRequire**

```ruby
# lib/backpressure/checks/hygiene/dead_require.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module Hygiene
      class DeadRequire < Check
        category "Hygiene"
        severity :warning
        files "**/*.rb"
        requires :source, :project

        REQUIRE_RELATIVE_PATTERN = /^\s*require_relative\s+["']([^"']+)["']/

        def check(context)
          dir = File.dirname(context.file_path)

          context.lines.each_with_index do |line, idx|
            match = line.match(REQUIRE_RELATIVE_PATTERN)
            next unless match

            relative_path = match[1]
            resolved = File.expand_path("#{relative_path}.rb", dir)

            unless File.exist?(resolved)
              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "require_relative \"#{relative_path}\" — file not found at #{resolved}")
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 7: Run specs — verify pass**

Run: `bundle exec rspec spec/backpressure/checks/hygiene/`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add lib/backpressure/checks/hygiene/ spec/backpressure/checks/hygiene/
git commit -m "feat: add Hygiene/TodoTracker and Hygiene/DeadRequire checks"
```

---

## Task 3: DesignSystem checks — Source-based (3 checks)

**Files:**
- Create: `lib/backpressure/checks/design_system/raw_html_ratchet.rb`
- Create: `lib/backpressure/checks/design_system/new_file_design_system_compliance.rb`
- Create: `lib/backpressure/checks/design_system/view_complexity.rb`
- Create: `spec/backpressure/checks/design_system/raw_html_ratchet_spec.rb`
- Create: `spec/backpressure/checks/design_system/new_file_design_system_compliance_spec.rb`
- Create: `spec/backpressure/checks/design_system/view_complexity_spec.rb`

- [ ] **Step 1: Write RawHTMLRatchet spec**

```ruby
# spec/backpressure/checks/design_system/raw_html_ratchet_spec.rb
# frozen_string_literal: true

require "backpressure/checks/design_system/raw_html_ratchet"

RSpec.describe Backpressure::Checks::DesignSystem::RawHTMLRatchet do
  def run_check(source, file_path: "app/views/glass_morph/test.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags raw HTML element calls" do
    source = <<~RUBY
      def view_template
        div(class: "wrapper") do
          span { text "hello" }
          Button(variant: :primary)
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(2)
    expect(check.violations.map(&:line)).to eq([2, 3])
  end

  it "does not flag component calls (uppercase)" do
    source = <<~RUBY
      def view_template
        Button(variant: :primary)
        GlassCard(variant: :solid)
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "scopes to glass_morph files" do
    expect(described_class.matches_file?("app/views/glass_morph/test.rb")).to be true
    expect(described_class.matches_file?("app/models/user.rb")).to be false
  end

  it "has ratchet :strict" do
    expect(described_class.ratchet_mode).to eq(:strict)
  end
end
```

- [ ] **Step 2: Implement RawHTMLRatchet**

```ruby
# lib/backpressure/checks/design_system/raw_html_ratchet.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class RawHTMLRatchet < Check
        category "DesignSystem"
        severity :error
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :source
        ratchet :strict

        RAW_ELEMENTS = %w[
          div span p a button input textarea select label
          h1 h2 h3 h4 h5 h6 small hr svg img i ul ol li
          table thead tbody tr td th form fieldset
        ].freeze

        PATTERN = /^\s+(#{RAW_ELEMENTS.join('|')})\s*[\(\s{]/

        def check(context)
          context.lines.each_with_index do |line, idx|
            next unless line.match?(PATTERN)

            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            violation(node, "Raw HTML element in GlassMorph file")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: Write NewFileDesignSystemCompliance spec**

```ruby
# spec/backpressure/checks/design_system/new_file_design_system_compliance_spec.rb
# frozen_string_literal: true

require "backpressure/checks/design_system/new_file_design_system_compliance"

RSpec.describe Backpressure::Checks::DesignSystem::NewFileDesignSystemCompliance do
  def run_check(source, file_path: "app/views/glass_morph/new_view.rb")
    context = Backpressure::Contexts::SourceContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags any raw HTML in new files" do
    source = <<~RUBY
      def view_template
        div(class: "wrapper")
        Button(variant: :primary)
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("New GlassMorph file")
  end

  it "passes clean files" do
    source = <<~RUBY
      def view_template
        Button(variant: :primary)
        GlassCard(variant: :solid)
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end
end
```

- [ ] **Step 4: Implement NewFileDesignSystemCompliance**

```ruby
# lib/backpressure/checks/design_system/new_file_design_system_compliance.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class NewFileDesignSystemCompliance < Check
        category "DesignSystem"
        severity :error
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :source
        ratchet false

        RAW_ELEMENTS = RawHTMLRatchet::RAW_ELEMENTS
        PATTERN = RawHTMLRatchet::PATTERN

        def check(context)
          raw_count = context.lines.count { |line| line.match?(PATTERN) }
          return if raw_count.zero?

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "New GlassMorph file contains #{raw_count} raw HTML element(s) — must use design system components only")
        end
      end
    end
  end
end
```

- [ ] **Step 5: Write ViewComplexity spec**

```ruby
# spec/backpressure/checks/design_system/view_complexity_spec.rb
# frozen_string_literal: true

require "backpressure/checks/design_system/view_complexity"

RSpec.describe Backpressure::Checks::DesignSystem::ViewComplexity do
  def run_check(source, file_path: "app/views/glass_morph/test.rb")
    context = Backpressure::Contexts::PhlexContext.new(source: source, file_path: file_path)
    check = described_class.new
    check.run(context)
    check
  end

  it "flags views with too many component calls" do
    components = (1..20).map { |i| "        Button(variant: :primary)" }.join("\n")
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          div do
#{components}
          end
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("20")
  end

  it "passes views under the threshold" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          div do
            Button(variant: :primary)
            GlassCard(variant: :solid)
          end
        end
      end
    RUBY
    check = run_check(source)
    expect(check.violations).to be_empty
  end

  it "skips files without view_template" do
    check = run_check("class Foo; end")
    expect(check.skipped?).to be true
  end
end
```

- [ ] **Step 6: Implement ViewComplexity**

```ruby
# lib/backpressure/checks/design_system/view_complexity.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class ViewComplexity < Check
        category "DesignSystem"
        severity :warning
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex

        MAX_COMPONENTS = 15

        def check(context)
          skip("No view_template found") unless context.tree

          count = context.tree.each_node.count
          return if count <= MAX_COMPONENTS

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "View renders #{count} components (max #{MAX_COMPONENTS}) — consider splitting")
        end
      end
    end
  end
end
```

- [ ] **Step 7: Run specs**

Run: `bundle exec rspec spec/backpressure/checks/design_system/`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add lib/backpressure/checks/design_system/ spec/backpressure/checks/design_system/
git commit -m "feat: add DesignSystem source checks — RawHTMLRatchet, NewFileCompliance, ViewComplexity"
```

---

## Task 4: DesignSystem checks — Phlex + ProjectIndex (5 checks)

**Files:**
- Create: `lib/backpressure/checks/design_system/component_catalog_enforcement.rb`
- Create: `lib/backpressure/checks/design_system/orphaned_component.rb`
- Create: `lib/backpressure/checks/design_system/component_coverage_drift.rb`
- Create: `lib/backpressure/checks/design_system/unused_component_slots.rb`
- Create: `lib/backpressure/checks/design_system/missing_test_id.rb`
- Create: `spec/backpressure/checks/design_system/component_catalog_enforcement_spec.rb`
- Create: `spec/backpressure/checks/design_system/orphaned_component_spec.rb`
- Create: `spec/backpressure/checks/design_system/component_coverage_drift_spec.rb`
- Create: `spec/backpressure/checks/design_system/unused_component_slots_spec.rb`
- Create: `spec/backpressure/checks/design_system/missing_test_id_spec.rb`

Each check follows the same TDD pattern: write spec → verify fail → implement → verify pass. Due to plan size, showing representative patterns. All checks follow identical structure.

- [ ] **Step 1: Write ComponentCatalogEnforcement spec**

```ruby
# spec/backpressure/checks/design_system/component_catalog_enforcement_spec.rb
# frozen_string_literal: true

require "backpressure/checks/design_system/component_catalog_enforcement"

RSpec.describe Backpressure::Checks::DesignSystem::ComponentCatalogEnforcement do
  def make_index(component_files)
    classes = component_files.map do |path|
      Backpressure::ProjectIndex::ClassEntry.new(
        name: File.basename(path, ".rb").split("_").map(&:capitalize).join,
        file: path,
        node: nil,
        superclass_name: nil
      )
    end
    Backpressure::ProjectIndex.new(classes: classes, files: component_files)
  end

  def run_check(source, component_files:, file_path: "app/views/glass_morph/test.rb")
    context = Backpressure::Contexts::PhlexContext.new(source: source, file_path: file_path)
    index = make_index(component_files)
    context.define_singleton_method(:project_index) { index }
    check = described_class.new
    check.run(context)
    check
  end

  it "flags raw button when Button atom exists" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          button(class: "btn")
        end
      end
    RUBY
    check = run_check(source, component_files: ["app/components/glass_morph/atoms/button.rb"])
    expect(check.violations.size).to eq(1)
    expect(check.violations.first.message).to include("Button")
  end

  it "passes when no matching atom exists" do
    source = <<~RUBY
      class TestView < Phlex::HTML
        def view_template
          canvas(width: 200)
        end
      end
    RUBY
    check = run_check(source, component_files: ["app/components/glass_morph/atoms/button.rb"])
    expect(check.violations).to be_empty
  end
end
```

- [ ] **Step 2: Implement ComponentCatalogEnforcement**

```ruby
# lib/backpressure/checks/design_system/component_catalog_enforcement.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class ComponentCatalogEnforcement < Check
        category "DesignSystem"
        severity :error
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex, :project

        def check(context)
          skip("No view_template found") unless context.tree

          catalog = build_catalog(context.project_index)
          return if catalog.empty?

          context.tree.each_node do |node|
            element_name = node.name.to_s.downcase
            next unless context.raw_html_elements.include?(node.name)

            replacement = catalog[element_name]
            next unless replacement

            violation(node.source_node, "Raw `#{node.name}` — use `#{replacement}` instead")
          end
        end

        private

        def build_catalog(index)
          catalog = {}
          atom_glob = "app/components/glass_morph/{atoms,molecules}/**/*.rb"
          index.classes_in(atom_glob).each do |entry|
            component_name = entry.name
            html_equiv = component_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
            catalog[html_equiv] = component_name
          end
          catalog
        end
      end
    end
  end
end
```

- [ ] **Step 3: Write + implement OrphanedComponent**

Spec tests that a component class in `atoms/` with zero references across all project files is flagged. Implementation uses `ProjectIndex#references_to` to check.

```ruby
# lib/backpressure/checks/design_system/orphaned_component.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class OrphanedComponent < Check
        category "DesignSystem"
        severity :warning
        files "app/components/glass_morph/**/*.rb"
        requires :source, :project

        def check(context)
          index = context.project_index
          component_classes = index.classes_in("app/components/glass_morph/**/*.rb")
          this_file_classes = component_classes.select { |c| c.file == context.file_path }

          this_file_classes.each do |klass|
            refs = index.references_to([klass])
            external_refs = refs.reject { |r| r.file == context.file_path }
            next unless external_refs.empty?

            node = klass.node || OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Component `#{klass.name}` is never referenced outside its own file")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Write + implement ComponentCoverageDrift**

```ruby
# lib/backpressure/checks/design_system/component_coverage_drift.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class ComponentCoverageDrift < Check
        category "DesignSystem"
        severity :error
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex
        ratchet :strict

        def check(context)
          skip("No view_template found") unless context.tree

          total = 0
          raw = 0
          context.tree.each_node do |node|
            total += 1
            raw += 1 if context.raw_html_elements.include?(node.name)
          end

          return if total.zero?

          coverage = ((total - raw).to_f / total * 100).round(1)
          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "Design system coverage: #{coverage}% (#{raw}/#{total} raw HTML nodes)")
        end
      end
    end
  end
end
```

- [ ] **Step 5: Write + implement UnusedComponentSlots**

```ruby
# lib/backpressure/checks/design_system/unused_component_slots.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class UnusedComponentSlots < Check
        category "DesignSystem"
        severity :warning
        files "app/components/glass_morph/**/*.rb"
        requires :source, :project

        YIELD_PATTERN = /\byield\b/

        def check(context)
          return unless context.source.match?(YIELD_PATTERN)

          index = context.project_index
          component_name = File.basename(context.file_path, ".rb").split("_").map(&:capitalize).join

          has_block_caller = index.files.any? do |file|
            next if file == context.file_path

            source = File.read(file)
            source.match?(/#{component_name}\s*[\(].*\bdo\b/m) || source.match?(/#{component_name}\s*\{/)
          end

          return if has_block_caller

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "`#{component_name}` defines yield slots but no caller passes a block")
        end
      end
    end
  end
end
```

- [ ] **Step 6: Write + implement MissingTestId**

```ruby
# lib/backpressure/checks/design_system/missing_test_id.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class MissingTestId < Check
        category "DesignSystem"
        severity :warning
        files "app/components/glass_morph/organisms/**/*.rb"
        requires :source, :project

        TID_PATTERN = /\btid\s*\(/

        def check(context)
          return if context.source.match?(TID_PATTERN)

          component_name = File.basename(context.file_path, ".rb")
          index = context.project_index
          referenced_in_cucumber = index.files.any? do |f|
            next unless f.end_with?("_steps.rb") || f.end_with?(".feature")

            File.read(f).include?(component_name)
          end

          return unless referenced_in_cucumber

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "Organism `#{component_name}` is referenced in Cucumber but has no `tid()` test ID")
        end
      end
    end
  end
end
```

- [ ] **Step 7: Write specs for all 5 checks, run**

Run: `bundle exec rspec spec/backpressure/checks/design_system/`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add lib/backpressure/checks/design_system/ spec/backpressure/checks/design_system/
git commit -m "feat: add DesignSystem Phlex+ProjectIndex checks — Catalog, Orphaned, Coverage, Slots, TestId"
```

---

## Task 5: DesignSystem checks — AI-powered (3 checks)

**Files:**
- Create: `lib/backpressure/checks/design_system/inconsistent_component_usage.rb`
- Create: `lib/backpressure/checks/design_system/duplicate_component_patterns.rb`
- Create: `checks/yaml/design_system/ai_invented_patterns.check.yml`
- Create: specs for each

- [ ] **Step 1: Write InconsistentComponentUsage as Ruby AiCheck**

```ruby
# lib/backpressure/checks/design_system/inconsistent_component_usage.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class InconsistentComponentUsage < AiCheck
        category "DesignSystem"
        severity :warning
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex, :project

        ai_config(
          provider: :default,
          temperature: 0,
          max_tokens: 1024,
          schema: {
            type: "array",
            items: {
              type: "object",
              properties: {
                line: { type: "integer" },
                message: { type: "string" }
              }
            }
          }
        )

        prompt_template <<~PROMPT
          You are a design system auditor. Analyze this Phlex component for
          inconsistent component usage patterns compared to the project norm.

          Flag components used with unusual kwargs that differ from the majority
          pattern across the codebase. Only report HIGH confidence findings.

          Source:
          {{source}}
        PROMPT
      end
    end
  end
end
```

- [ ] **Step 2: Write DuplicateComponentPatterns**

```ruby
# lib/backpressure/checks/design_system/duplicate_component_patterns.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module DesignSystem
      class DuplicateComponentPatterns < AiCheck
        category "DesignSystem"
        severity :info
        files "app/{views,components}/glass_morph/**/*.rb"
        requires :phlex, :project

        ai_config(
          provider: :default,
          temperature: 0,
          max_tokens: 1024,
          schema: {
            type: "array",
            items: {
              type: "object",
              properties: {
                line: { type: "integer" },
                message: { type: "string" }
              }
            }
          }
        )

        prompt_template <<~PROMPT
          Analyze this Phlex component for component subtrees that appear
          duplicated. If a group of 3+ components appears in the same
          arrangement elsewhere, suggest extracting a shared organism.

          Only flag HIGH confidence duplications.

          Source:
          {{source}}
        PROMPT
      end
    end
  end
end
```

- [ ] **Step 3: Write AIInventedPatterns YAML check**

```yaml
# checks/yaml/design_system/ai_invented_patterns.check.yml
name: AIInventedPatterns
category: DesignSystem
severity: warning
files: "app/{views,components}/glass_morph/**/*.rb"
requires:
  - source
ai:
  provider: default
  temperature: 0
  max_tokens: 1024
  schema:
    type: array
    items:
      type: object
      properties:
        line:
          type: integer
        message:
          type: string
prompt: |
  You are a GlassMorph design system auditor.

  Review this Phlex component for raw HTML that should use a design system
  component instead. Look for:
  - Any raw HTML element (div, span, p, a, button, input, etc.)
    with styling classes that replicate what an atom/molecule does
  - Inline styles that a component parameter handles
  - Bootstrap utility class combinations an atom wraps
  - Custom CSS classes that duplicate component functionality
  - Any HTML structure that looks like it reinvents a component

  Only flag HIGH and MEDIUM confidence findings.
  Do NOT flag: plain text, simple yield blocks, or elements with no styling.

  Source:
  {{source}}
```

- [ ] **Step 4: Write specs for all 3, run**

Run: `bundle exec rspec spec/backpressure/checks/design_system/`
Expected: All pass (AI checks produce empty violations with :test provider)

- [ ] **Step 5: Commit**

```bash
git add lib/backpressure/checks/design_system/ checks/yaml/design_system/ spec/backpressure/checks/design_system/
git commit -m "feat: add DesignSystem AI checks — InconsistentUsage, DuplicatePatterns, AIInventedPatterns"
```

---

## Task 6: Architecture checks (3 checks)

**Files:**
- Create: `lib/backpressure/checks/architecture/circular_service_dependency.rb`
- Create: `lib/backpressure/checks/architecture/orphaned_service.rb`
- Create: `lib/backpressure/checks/architecture/service_fan_out.rb`
- Create: specs for each

- [ ] **Step 1: Write + implement CircularServiceDependency**

```ruby
# lib/backpressure/checks/architecture/circular_service_dependency.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module Architecture
      class CircularServiceDependency < Check
        category "Architecture"
        severity :error
        files "app/services/**/*.rb"
        requires :ast, :project

        SERVICE_CALL_PATTERN = /\.(run|new|call)\b/

        def check(context)
          index = context.project_index
          services = index.classes_in("app/services/**/*.rb")
          service_names = services.map(&:name).to_set

          this_class = services.find { |c| c.file == context.file_path }
          return unless this_class

          deps = find_service_deps(context.ast, service_names)
          deps.each do |dep_name|
            dep_entry = services.find { |c| c.name == dep_name }
            next unless dep_entry

            reverse_deps = find_service_deps_in_file(dep_entry.file, service_names)
            next unless reverse_deps.include?(this_class.name)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Circular dependency: #{this_class.name} ↔ #{dep_name}")
          end
        end

        private

        def find_service_deps(ast, service_names)
          deps = Set.new
          ast.each_node(:send) do |node|
            receiver = node.children[0]
            next unless receiver&.type == :const

            name = receiver.source rescue nil
            deps << name if name && service_names.include?(name)
          end
          deps
        end

        def find_service_deps_in_file(file_path, service_names)
          source = File.read(file_path)
          processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
          return Set.new unless processed.ast

          find_service_deps(processed.ast, service_names)
        end
      end
    end
  end
end
```

- [ ] **Step 2: Write + implement OrphanedService**

```ruby
# lib/backpressure/checks/architecture/orphaned_service.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module Architecture
      class OrphanedService < Check
        category "Architecture"
        severity :warning
        files "app/services/**/*.rb"
        requires :source, :project

        def check(context)
          index = context.project_index
          this_classes = index.classes_in(context.file_path)
          return if this_classes.empty?

          this_classes.each do |klass|
            refs = index.references_to([klass])
            external_refs = refs.reject { |r| r.file == context.file_path }
            next unless external_refs.empty?

            node = klass.node || OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Service `#{klass.name}` is never referenced outside its own file")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: Write + implement ServiceFanOut**

```ruby
# lib/backpressure/checks/architecture/service_fan_out.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module Architecture
      class ServiceFanOut < Check
        category "Architecture"
        severity :warning
        files "app/services/**/*.rb"
        requires :ast, :project

        MAX_DEPENDENCIES = 5

        def check(context)
          index = context.project_index
          services = index.classes_in("app/services/**/*.rb")
          service_names = services.map(&:name).to_set

          deps = Set.new
          context.ast.each_node(:send) do |node|
            receiver = node.children[0]
            next unless receiver&.type == :const

            name = receiver.source rescue nil
            deps << name if name && service_names.include?(name)
          end

          return if deps.size <= MAX_DEPENDENCIES

          node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
          violation(node, "Service calls #{deps.size} other services (max #{MAX_DEPENDENCIES}): #{deps.to_a.join(', ')}")
        end
      end
    end
  end
end
```

- [ ] **Step 4: Write specs, run**

Run: `bundle exec rspec spec/backpressure/checks/architecture/`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add lib/backpressure/checks/architecture/ spec/backpressure/checks/architecture/
git commit -m "feat: add Architecture checks — CircularServiceDependency, OrphanedService, ServiceFanOut"
```

---

## Task 7: AI Prompt Safety checks (5 checks)

**Files:**
- Create: `checks/yaml/ai/prompt_injection_surface.check.yml`
- Create: `checks/yaml/ai/pii_in_system_prompt.check.yml`
- Create: `checks/yaml/ai/prompt_leakage_risk.check.yml`
- Create: `lib/backpressure/checks/ai/prompt_safety/no_input_sanitization.rb`
- Create: `lib/backpressure/checks/ai/prompt_safety/system_prompt_drift.rb`
- Create: specs for each

- [ ] **Step 1: Create 3 YAML checks**

```yaml
# checks/yaml/ai/prompt_injection_surface.check.yml
name: PromptInjectionSurface
category: AI/PromptSafety
severity: error
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 1024
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Analyze this RAAF agent/prompt file for prompt injection vulnerabilities.

  Check if:
  - User input appears BEFORE system constraints (allows override)
  - String interpolation injects unescaped user data into system prompts
  - The prompt lacks instruction hierarchy (system > user boundary)
  - User-controlled content could close/reopen instruction blocks

  Only report findings where injection is structurally possible.

  Source:
  {{source}}
```

```yaml
# checks/yaml/ai/pii_in_system_prompt.check.yml
name: PIIInSystemPrompt
category: AI/PromptSafety
severity: error
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 1024
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Scan this AI agent/prompt file for hardcoded PII or secrets.

  Flag: email addresses, names, phone numbers, API keys, tokens,
  internal URLs (not example.com), passwords, or database credentials
  embedded directly in prompt strings.

  Do NOT flag: template variables, environment variable references,
  or configuration lookups.

  Source:
  {{source}}
```

```yaml
# checks/yaml/ai/prompt_leakage_risk.check.yml
name: PromptLeakageRisk
category: AI/PromptSafety
severity: warning
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 1024
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Check this AI agent/prompt for information leakage risks.

  Flag prompts that expose:
  - Internal tool names or class names to the model
  - Database schema details
  - Internal API endpoints or architecture
  - System role descriptions that could be extracted by users

  Source:
  {{source}}
```

- [ ] **Step 2: Write NoInputSanitization Ruby check**

```ruby
# lib/backpressure/checks/ai/prompt_safety/no_input_sanitization.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module PromptSafety
        class NoInputSanitization < Check
          category "AI/PromptSafety"
          severity :error
          files "app/ai/**/*.rb"
          requires :ast

          def check(context)
            context.ast.each_node(:def) do |def_node|
              next unless def_node.children[0] == :user

              body = def_node.children[2]
              next unless body

              body.each_node(:dstr, :send) do |node|
                if node.type == :dstr
                  violation(node, "String interpolation in `def user` — user data may reach prompt unsanitized")
                end
              end
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: Write SystemPromptDrift Ruby AiCheck**

```ruby
# lib/backpressure/checks/ai/prompt_safety/system_prompt_drift.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module PromptSafety
        class SystemPromptDrift < AiCheck
          category "AI/PromptSafety"
          severity :info
          files "app/ai/**/*.rb"
          requires :source, :project

          ai_config(
            provider: :default,
            temperature: 0,
            max_tokens: 512,
            schema: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  line: { type: "integer" },
                  message: { type: "string" }
                }
              }
            }
          )

          prompt_template <<~PROMPT
            Check if this agent's system prompt is near-identical to another
            agent's system prompt. If >80% of the system prompt text is shared
            with another file, flag it for extraction into a shared base prompt.

            Source:
            {{source}}
          PROMPT
        end
      end
    end
  end
end
```

- [ ] **Step 4: Write specs for all 5, run**

Run: `bundle exec rspec spec/backpressure/checks/ai/prompt_safety/`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add checks/yaml/ai/ lib/backpressure/checks/ai/prompt_safety/ spec/backpressure/checks/ai/prompt_safety/
git commit -m "feat: add AI/PromptSafety checks — Injection, PII, Leakage, Sanitization, Drift"
```

---

## Task 8: AI Output Safety checks (5 checks)

**Files:**
- Create: `lib/backpressure/checks/ai/output_safety/unvalidated_output.rb`
- Create: `lib/backpressure/checks/ai/output_safety/output_to_sql.rb`
- Create: `lib/backpressure/checks/ai/output_safety/output_to_html.rb`
- Create: `checks/yaml/ai/hallucination_guard_missing.check.yml`
- Create: `checks/yaml/ai/schema_field_coverage.check.yml`
- Create: specs for each

- [ ] **Step 1: Create 2 YAML checks (HallucinationGuardMissing, SchemaFieldCoverage)**

```yaml
# checks/yaml/ai/hallucination_guard_missing.check.yml
name: HallucinationGuardMissing
category: AI/OutputSafety
severity: warning
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 1024
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Analyze this AI agent for hallucination guard gaps.

  Flag if the agent returns IDs, URLs, entity names, or database
  references but the code does not validate that referenced objects
  actually exist (e.g., no find_by, exists?, or similar lookup after
  the AI call).

  Source:
  {{source}}
```

```yaml
# checks/yaml/ai/schema_field_coverage.check.yml
name: SchemaFieldCoverage
category: AI/OutputSafety
severity: warning
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 1024
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Compare the output schema definition with the system/user prompt.

  Flag fields declared in the schema that the prompt never mentions
  or asks the model to produce. The model may hallucinate values for
  schema fields it was never instructed about.

  Also flag if the prompt asks for information not captured by any
  schema field.

  Source:
  {{source}}
```

- [ ] **Step 2: Write 3 Ruby checks (UnvalidatedOutput, OutputToSQL, OutputToHTML)**

```ruby
# lib/backpressure/checks/ai/output_safety/unvalidated_output.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module OutputSafety
        class UnvalidatedOutput < Check
          category "AI/OutputSafety"
          severity :error
          files "app/{controllers,services}/**/*.rb"
          requires :ast

          AGENT_CALL = /\.(run|call)\z/
          VALIDATION = /\.(success\?|valid\?|errors|validate!)/

          def check(context)
            source = context.source
            return unless source.match?(/\.run\b/)

            context.ast.each_node(:send) do |node|
              method_name = node.children[1]
              next unless method_name == :run

              receiver = node.children[0]
              next unless receiver

              line_num = node.loc.line
              remaining = context.source.lines[line_num - 1..line_num + 5]&.join || ""
              unless remaining.match?(/\.success\?|\.valid\?|\.errors|validate!/)
                violation(node, "Agent `.run` result used without checking `.success?` or validating output")
              end
            end
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/output_safety/output_to_sql.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module OutputSafety
        class OutputToSQL < Check
          category "AI/OutputSafety"
          severity :error
          files "app/**/*.rb"
          requires :ast

          QUERY_METHODS = %i[where find_by select joins order group having].freeze

          def check(context)
            context.ast.each_node(:send) do |node|
              method_name = node.children[1]
              next unless QUERY_METHODS.include?(method_name)

              args = node.children[2..]
              args&.each do |arg|
                next unless arg.is_a?(RuboCop::AST::Node)

                if arg.type == :dstr
                  violation(node, "String interpolation in `#{method_name}` — potential SQL injection via LLM output")
                end
              end
            end
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/output_safety/output_to_html.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module OutputSafety
        class OutputToHTML < Check
          category "AI/OutputSafety"
          severity :error
          files "app/{views,components}/**/*.rb"
          requires :source

          RAW_OUTPUT_PATTERN = /raw\s*\(|html_safe|==\s/

          def check(context)
            context.lines.each_with_index do |line, idx|
              next unless line.match?(RAW_OUTPUT_PATTERN)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Unescaped output (`raw`, `html_safe`, or `==`) — potential XSS if content comes from LLM")
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: Write specs, run**

Run: `bundle exec rspec spec/backpressure/checks/ai/output_safety/`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add checks/yaml/ai/ lib/backpressure/checks/ai/output_safety/ spec/backpressure/checks/ai/output_safety/
git commit -m "feat: add AI/OutputSafety checks — UnvalidatedOutput, OutputToSQL, OutputToHTML, HallucinationGuard, SchemaFieldCoverage"
```

---

## Task 9: AI Cost & Resource checks (5 checks)

**Files:**
- Create: `lib/backpressure/checks/ai/cost/no_max_tokens_limit.rb`
- Create: `lib/backpressure/checks/ai/cost/unbounded_retry_loop.rb`
- Create: `lib/backpressure/checks/ai/cost/missing_cacheability.rb`
- Create: `lib/backpressure/checks/ai/cost/large_context_window.rb`
- Create: `checks/yaml/ai/expensive_model_for_simple_task.check.yml`
- Create: specs for each

- [ ] **Step 1: Write NoMaxTokensLimit**

```ruby
# lib/backpressure/checks/ai/cost/no_max_tokens_limit.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Cost
        class NoMaxTokensLimit < Check
          category "AI/Cost"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return if context.source.match?(/max_tokens/)

            return unless context.source.match?(/\.complete\b|\.chat\b|\.run\b/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "AI call without `max_tokens` — unbounded response cost")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: Write UnboundedRetryLoop**

```ruby
# lib/backpressure/checks/ai/cost/unbounded_retry_loop.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Cost
        class UnboundedRetryLoop < Check
          category "AI/Cost"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          RETRY_PATTERN = /\bretry\b/
          MAX_PATTERN = /max_attempts|max_retries|retry_count|attempts\s*[<>=]/

          def check(context)
            return unless context.source.match?(RETRY_PATTERN)
            return if context.source.match?(MAX_PATTERN)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(RETRY_PATTERN)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "`retry` without max attempt cap — potential runaway cost")
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: Write MissingCacheability, LargeContextWindow**

```ruby
# lib/backpressure/checks/ai/cost/missing_cacheability.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Cost
        class MissingCacheability < Check
          category "AI/Cost"
          severity :info
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/temperature:\s*0/)
            return if context.source.match?(/cache|memoize|Rails\.cache/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Deterministic prompt (temperature: 0) without caching — repeated calls waste tokens")
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/cost/large_context_window.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Cost
        class LargeContextWindow < Check
          category "AI/Cost"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          MAX_PROMPT_KB = 50

          def check(context)
            return unless context.source.match?(/\.read\b|File\.read|\.body\b/)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(/File\.read|\.read\b.*\.join/)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Large file read into prompt context — consider summarization to reduce token cost")
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Write ExpensiveModelForSimpleTask YAML**

```yaml
# checks/yaml/ai/expensive_model_for_simple_task.check.yml
name: ExpensiveModelForSimpleTask
category: AI/Cost
severity: info
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 512
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Analyze this AI agent. If the task is simple (classification, yes/no,
  extraction, formatting) but uses a large/expensive model (opus, gpt-4,
  claude-3-opus), flag it. Simple tasks should use smaller models
  (haiku, gpt-4o-mini, claude-3-haiku).

  Source:
  {{source}}
```

- [ ] **Step 5: Write specs, run**

Run: `bundle exec rspec spec/backpressure/checks/ai/cost/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add lib/backpressure/checks/ai/cost/ checks/yaml/ai/ spec/backpressure/checks/ai/cost/
git commit -m "feat: add AI/Cost checks — NoMaxTokens, UnboundedRetry, MissingCacheability, LargeContext, ExpensiveModel"
```

---

## Task 10: AI Observability checks (4 checks)

**Files:**
- Create: `lib/backpressure/checks/ai/observability/no_logging.rb`
- Create: `lib/backpressure/checks/ai/observability/no_trace_id.rb`
- Create: `lib/backpressure/checks/ai/observability/silent_failure.rb`
- Create: `lib/backpressure/checks/ai/observability/audit_trail_missing.rb`
- Create: specs for each

- [ ] **Step 1: Implement all 4 checks**

```ruby
# lib/backpressure/checks/ai/observability/no_logging.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Observability
        class NoLogging < Check
          category "AI/Observability"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return if context.source.match?(/RAAF\.logger|Rails\.logger|logger\./)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent has no logging — AI decisions will be untraceable")
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/observability/no_trace_id.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Observability
        class NoTraceId < Check
          category "AI/Observability"
          severity :info
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/\.run\b/)
            return if context.source.match?(/trace_id|correlation_id|request_id/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent calls other agents without passing a trace/correlation ID")
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/observability/silent_failure.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Observability
        class SilentFailure < Check
          category "AI/Observability"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            context.lines.each_with_index do |line, idx|
              next unless line.match?(/rescue\b/)

              remaining = context.lines[idx + 1..idx + 3]&.join || ""
              next if remaining.match?(/log|raise|notify|error_result/)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Rescue block without logging or re-raising — silent failure")
            end
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/observability/audit_trail_missing.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Observability
        class AuditTrailMissing < Check
          category "AI/Observability"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          MUTATION_PATTERN = /\.save!?|\.update!?|\.create!?|\.destroy!?|\.delete/

          def check(context)
            return unless context.source.match?(MUTATION_PATTERN)
            return if context.source.match?(/audit|log_action|paper_trail|track_change/)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(MUTATION_PATTERN)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Agent mutates DB records without audit trail logging")
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: Write specs, run**

Run: `bundle exec rspec spec/backpressure/checks/ai/observability/`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add lib/backpressure/checks/ai/observability/ spec/backpressure/checks/ai/observability/
git commit -m "feat: add AI/Observability checks — NoLogging, NoTraceId, SilentFailure, AuditTrailMissing"
```

---

## Task 11: AI Tool & Scope Safety checks (4 checks)

**Files:**
- Create: `lib/backpressure/checks/ai/tool_safety/overprivileged_tool_set.rb`
- Create: `lib/backpressure/checks/ai/tool_safety/tool_without_confirmation.rb`
- Create: `lib/backpressure/checks/ai/tool_safety/unbounded_tool_execution.rb`
- Create: `lib/backpressure/checks/ai/tool_safety/tool_chain_depth.rb`
- Create: specs for each

- [ ] **Step 1: Implement all 4**

```ruby
# lib/backpressure/checks/ai/tool_safety/overprivileged_tool_set.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module ToolSafety
        class OverprivilegedToolSet < AiCheck
          category "AI/ToolSafety"
          severity :warning
          files "app/ai/agents/**/*.rb"
          requires :source

          ai_config(
            provider: :default,
            temperature: 0,
            max_tokens: 512,
            schema: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  line: { type: "integer" },
                  message: { type: "string" }
                }
              }
            }
          )

          prompt_template <<~PROMPT
            Analyze this RAAF agent's tool set. If the agent has tools
            that can write, delete, or modify data but the agent's task
            (based on its system prompt) only requires reading data, flag
            the overprivileged tools. Principle of least privilege.

            Source:
            {{source}}
          PROMPT
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/tool_safety/tool_without_confirmation.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module ToolSafety
        class ToolWithoutConfirmation < Check
          category "AI/ToolSafety"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          DESTRUCTIVE = /delete|destroy|remove|send_email|send_notification|transfer|publish/i

          def check(context)
            return unless context.source.match?(DESTRUCTIVE)
            return if context.source.match?(/confirm|approve|human_review|requires_approval/)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(DESTRUCTIVE)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Destructive tool operation without human-in-the-loop confirmation gate")
            end
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/tool_safety/unbounded_tool_execution.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module ToolSafety
        class UnboundedToolExecution < Check
          category "AI/ToolSafety"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/build_tool|register_tool|def execute/)
            return if context.source.match?(/timeout|Timeout\.timeout|with_timeout/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Tool execution without timeout — agent could hang indefinitely")
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/tool_safety/tool_chain_depth.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module ToolSafety
        class ToolChainDepth < Check
          category "AI/ToolSafety"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          MAX_DEPTH = 5

          def check(context)
            return unless context.source.match?(/Pipeline|>>/)

            agent_calls = context.source.scan(/>>/).size + 1
            return if agent_calls <= MAX_DEPTH

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Pipeline chains #{agent_calls} agents (max #{MAX_DEPTH}) — increases hallucination compounding risk")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: Write specs, run, commit**

```bash
git add lib/backpressure/checks/ai/tool_safety/ spec/backpressure/checks/ai/tool_safety/
git commit -m "feat: add AI/ToolSafety checks — OverprivilegedToolSet, ToolWithoutConfirmation, UnboundedExecution, ToolChainDepth"
```

---

## Task 12: AI Data Governance checks (3 checks)

**Files:**
- Create: `lib/backpressure/checks/ai/data_governance/sensitive_data_in_prompt.rb`
- Create: `lib/backpressure/checks/ai/data_governance/cross_tenant_data_leak.rb`
- Create: `lib/backpressure/checks/ai/data_governance/external_api_key_exposure.rb`
- Create: specs for each

- [ ] **Step 1: Implement all 3**

```ruby
# lib/backpressure/checks/ai/data_governance/sensitive_data_in_prompt.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module DataGovernance
        class SensitiveDataInPrompt < AiCheck
          category "AI/DataGovernance"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          ai_config(provider: :default, temperature: 0, max_tokens: 512,
            schema: { type: "array", items: { type: "object",
              properties: { line: { type: "integer" }, message: { type: "string" } } } })

          prompt_template <<~PROMPT
            Analyze this AI agent for sensitive data exposure.

            Flag if PII fields (email, phone, ssn, address, date_of_birth,
            salary, credit_card) from model associations are loaded into
            the prompt context without field filtering (e.g., `.select` or
            `.pluck` to pick only needed fields).

            Source:
            {{source}}
          PROMPT
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/data_governance/cross_tenant_data_leak.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module DataGovernance
        class CrossTenantDataLeak < Check
          category "AI/DataGovernance"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          QUERY_PATTERN = /\.where\b|\.find\b|\.find_by\b|\.all\b/
          TENANT_PATTERN = /acts_as_tenant|current_account|Current\.account/

          def check(context)
            return unless context.source.match?(QUERY_PATTERN)
            return if context.source.match?(TENANT_PATTERN)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(QUERY_PATTERN)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Database query in agent without tenant scoping — potential cross-tenant data leak")
            end
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/data_governance/external_api_key_exposure.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module DataGovernance
        class ExternalAPIKeyExposure < Check
          category "AI/DataGovernance"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          KEY_PATTERN = /api[_-]?key|secret[_-]?key|access[_-]?token|bearer/i
          ENV_PATTERN = /ENV\[|Rails\.application\.credentials/

          def check(context)
            context.lines.each_with_index do |line, idx|
              next unless line.match?(KEY_PATTERN)
              next if line.match?(ENV_PATTERN)
              next if line.match?(/^\s*#/)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "API key reference that could leak via LLM prompt — use ENV or credentials instead")
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: Write specs, run, commit**

```bash
git add lib/backpressure/checks/ai/data_governance/ spec/backpressure/checks/ai/data_governance/
git commit -m "feat: add AI/DataGovernance checks — SensitiveDataInPrompt, CrossTenantDataLeak, ExternalAPIKeyExposure"
```

---

## Task 13: AI Human Oversight + Testing checks (7 checks)

**Files:**
- Create: `lib/backpressure/checks/ai/human_oversight/autonomous_state_change.rb`
- Create: `lib/backpressure/checks/ai/human_oversight/no_fallback_path.rb`
- Create: `lib/backpressure/checks/ai/human_oversight/user_facing_without_review.rb`
- Create: `lib/backpressure/checks/ai/testing/agent_without_spec.rb`
- Create: `lib/backpressure/checks/ai/testing/prompt_without_test.rb`
- Create: `lib/backpressure/checks/ai/testing/determinism_untested.rb`
- Create: `checks/yaml/ai/no_edge_case_tests.check.yml`
- Create: specs for each

- [ ] **Step 1: Implement Human Oversight (3 checks)**

```ruby
# lib/backpressure/checks/ai/human_oversight/autonomous_state_change.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module HumanOversight
        class AutonomousStateChange < Check
          category "AI/HumanOversight"
          severity :error
          files "app/ai/**/*.rb"
          requires :source

          STATE_CHANGE = /\.update!?\(.*status|\.transition_to|state_machine|\.save!/

          def check(context)
            return unless context.source.match?(STATE_CHANGE)
            return if context.source.match?(/requires_approval|human_review|approval_gate/)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(STATE_CHANGE)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Agent changes record state without human approval step")
            end
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/human_oversight/no_fallback_path.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module HumanOversight
        class NoFallbackPath < Check
          category "AI/HumanOversight"
          severity :warning
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/\.run\b/)
            return if context.source.match?(/rescue|fallback|default_response|error_result/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent has no fallback path — failures will surface as raw errors")
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/human_oversight/user_facing_without_review.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module HumanOversight
        class UserFacingWithoutReview < Check
          category "AI/HumanOversight"
          severity :warning
          files "app/{controllers,views}/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/agent.*result|\.run\b.*response/)
            return if context.source.match?(/moderate|review|filter|sanitize/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent output displayed to end user without moderation/review")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: Implement AI Testing (3 Ruby + 1 YAML)**

```ruby
# lib/backpressure/checks/ai/testing/agent_without_spec.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Testing
        class AgentWithoutSpec < Check
          category "AI/Testing"
          severity :warning
          files "app/ai/agents/**/*.rb"
          requires :source, :project

          def check(context)
            agent_file = context.file_path
            spec_file = agent_file.sub("app/ai/agents/", "spec/ai/agents/").sub(".rb", "_spec.rb")

            unless context.project_index.files.include?(spec_file) || File.exist?(spec_file)
              node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
              violation(node, "Agent has no corresponding spec file at #{spec_file}")
            end
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/testing/prompt_without_test.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Testing
        class PromptWithoutTest < Check
          category "AI/Testing"
          severity :warning
          files "app/ai/prompts/**/*.rb"
          requires :source, :project

          def check(context)
            prompt_file = context.file_path
            spec_file = prompt_file.sub("app/ai/prompts/", "spec/ai/prompts/").sub(".rb", "_spec.rb")

            unless context.project_index.files.include?(spec_file) || File.exist?(spec_file)
              node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
              violation(node, "Prompt class has no spec at #{spec_file}")
            end
          end
        end
      end
    end
  end
end
```

```ruby
# lib/backpressure/checks/ai/testing/determinism_untested.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module Testing
        class DeterminismUntested < Check
          category "AI/Testing"
          severity :info
          files "app/ai/**/*.rb"
          requires :source

          def check(context)
            return unless context.source.match?(/temperature:\s*0/)

            node = OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0))
            violation(node, "Agent uses temperature: 0 — spec should assert deterministic output on identical input")
          end
        end
      end
    end
  end
end
```

```yaml
# checks/yaml/ai/no_edge_case_tests.check.yml
name: NoEdgeCaseTests
category: AI/Testing
severity: info
files: "spec/ai/**/*_spec.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 512
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Analyze this AI agent spec. Check if it only tests the happy path.

  Flag if missing tests for: malformed LLM output, timeout/error
  responses, refusal/empty responses, schema validation failures,
  or boundary conditions.

  Source:
  {{source}}
```

- [ ] **Step 3: Write specs, run, commit**

```bash
git add lib/backpressure/checks/ai/human_oversight/ lib/backpressure/checks/ai/testing/ checks/yaml/ai/ spec/backpressure/checks/ai/
git commit -m "feat: add AI/HumanOversight and AI/Testing checks"
```

---

## Task 14: RAAF YAML checks (3 checks)

**Files:**
- Create: `checks/yaml/raaf/prompt_clarity.check.yml`
- Create: `checks/yaml/raaf/schema_prompt_mismatch.check.yml`
- Create: `checks/yaml/raaf/tool_description_quality.check.yml`
- Create: specs for each

- [ ] **Step 1: Create 3 YAML files**

```yaml
# checks/yaml/raaf/prompt_clarity.check.yml
name: PromptClarity
category: RAAF
severity: warning
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 512
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Analyze this RAAF agent's system prompt for clarity.

  Flag: vague instructions ("do your best", "be helpful"), contradictory
  requirements, missing output format specification, ambiguous scope,
  or instructions that could be interpreted multiple ways.

  Source:
  {{source}}
```

```yaml
# checks/yaml/raaf/schema_prompt_mismatch.check.yml
name: SchemaPromptMismatch
category: RAAF
severity: warning
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 512
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Compare the output schema with the system/user prompt in this agent.

  Flag: fields in the schema that the prompt never asks for,
  information the prompt requests but no schema field captures,
  or type mismatches between what the prompt describes and schema types.

  Source:
  {{source}}
```

```yaml
# checks/yaml/raaf/tool_description_quality.check.yml
name: ToolDescriptionQuality
category: RAAF
severity: info
files: "app/ai/**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 512
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Review tool descriptions in this RAAF agent.

  Flag descriptions that are: too terse (<10 words), missing parameter
  documentation, ambiguous about when to use the tool, or missing
  example inputs/outputs.

  Source:
  {{source}}
```

- [ ] **Step 2: Write specs, run, commit**

```bash
git add checks/yaml/raaf/ spec/backpressure/checks/raaf/
git commit -m "feat: add RAAF YAML checks — PromptClarity, SchemaPromptMismatch, ToolDescriptionQuality"
```

---

## Task 15: Remaining checks — MultiTenancy, Testing, Convention (3 checks)

**Files:**
- Create: `lib/backpressure/checks/multi_tenancy/unscoped_cross_file_query.rb`
- Create: `lib/backpressure/checks/testing/factory_without_spec.rb`
- Create: `checks/yaml/convention/commented_out_code.check.yml`
- Create: specs for each

- [ ] **Step 1: Implement UnscopedCrossFileQuery**

```ruby
# lib/backpressure/checks/multi_tenancy/unscoped_cross_file_query.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module MultiTenancy
      class UnscopedCrossFileQuery < Check
        category "MultiTenancy"
        severity :error
        files "app/services/**/*.rb"
        requires :source

        QUERY_METHODS = /\.(where|find|find_by|all|first|last|count|pluck)\b/
        TENANT_SAFE = /acts_as_tenant|Current\.account|current_account|ActsAsTenant/

        def check(context)
          return if context.source.match?(TENANT_SAFE)

          context.lines.each_with_index do |line, idx|
            next unless line.match?(QUERY_METHODS)

            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            violation(node, "Database query in service without tenant scoping — verify model uses `acts_as_tenant`")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: Implement FactoryWithoutSpec**

```ruby
# lib/backpressure/checks/testing/factory_without_spec.rb
# frozen_string_literal: true

module Backpressure
  module Checks
    module Testing
      class FactoryWithoutSpec < Check
        category "Testing"
        severity :info
        files "spec/factories/**/*.rb"
        requires :source, :project

        FACTORY_PATTERN = /factory\s+:(\w+)/

        def check(context)
          context.lines.each_with_index do |line, idx|
            match = line.match(FACTORY_PATTERN)
            next unless match

            factory_name = match[1]
            referenced = context.project_index.files.any? do |f|
              next unless f.match?(%r{spec/.*_spec\.rb\z})

              File.read(f).include?(factory_name)
            end

            next if referenced

            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            violation(node, "Factory `:#{factory_name}` is never referenced in any spec file")
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: Create CommentedOutCode YAML**

```yaml
# checks/yaml/convention/commented_out_code.check.yml
name: CommentedOutCode
category: Convention
severity: warning
files: "**/*.rb"
ai:
  provider: default
  temperature: 0
  max_tokens: 1024
  schema:
    type: array
    items:
      type: object
      properties:
        line: { type: integer }
        message: { type: string }
prompt: |
  Scan this Ruby file for commented-out code blocks.

  Flag blocks of 2+ consecutive lines that are commented-out Ruby code
  (not documentation comments). Look for commented-out method definitions,
  class declarations, assignments, control flow, or method calls.

  Do NOT flag: legitimate documentation, TODO/FIXME comments, or
  single-line disable annotations.

  Source:
  {{source}}
```

- [ ] **Step 4: Write specs, run, commit**

```bash
git add lib/backpressure/checks/multi_tenancy/ lib/backpressure/checks/testing/ checks/yaml/convention/ spec/backpressure/checks/
git commit -m "feat: add MultiTenancy, Testing, and Convention checks"
```

---

## Task 16: Full integration test

**Files:**
- Modify: `spec/integration/full_flow_spec.rb`

- [ ] **Step 1: Add integration test that loads all checks**

```ruby
# Add to spec/integration/full_flow_spec.rb
it "loads all check classes from checks directories" do
  registry = Backpressure::CheckRegistry.new
  checks_dir = File.expand_path("../../lib/backpressure/checks", __dir__)
  registry.load_from(checks_dir)

  expect(registry.all.size).to be >= 43

  categories = registry.all.map { |c| c.check_category }.uniq.sort
  expect(categories).to include("Hygiene", "DesignSystem", "Architecture", "AI/Cost")
end

it "loads all YAML checks" do
  yaml_dir = File.expand_path("../../checks/yaml", __dir__)
  checks = Backpressure::YamlLoader.load_all(yaml_dir)

  expect(checks.size).to eq(12)
  expect(checks.map { |c| c.check_name }).to include("PromptClarity", "CommentedOutCode")
end
```

- [ ] **Step 2: Run full suite**

Run: `bundle exec rspec`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add spec/integration/
git commit -m "test: add integration test for all 55 checks"
```

---

## Summary

| Task | Checks | Type |
|------|--------|------|
| 0 | — | Dependency |
| 1 | — | Framework specs |
| 2 | 2 | Hygiene (Source, ProjectIndex) |
| 3 | 3 | DesignSystem (Source, Phlex) |
| 4 | 5 | DesignSystem (Phlex + ProjectIndex) |
| 5 | 3 | DesignSystem (AI) |
| 6 | 3 | Architecture (ProjectIndex) |
| 7 | 5 | AI/PromptSafety |
| 8 | 5 | AI/OutputSafety |
| 9 | 5 | AI/Cost |
| 10 | 4 | AI/Observability |
| 11 | 4 | AI/ToolSafety |
| 12 | 3 | AI/DataGovernance |
| 13 | 7 | AI/HumanOversight + AI/Testing |
| 14 | 3 | RAAF (YAML) |
| 15 | 3 | MultiTenancy + Testing + Convention |
| 16 | — | Integration test |
| **Total** | **55** | |

**Tasks 2-15 are independent and can run in parallel via subagent-driven-development.**
