# Backpressure Gem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Ruby gem that unifies deterministic, component-tree, and AI-powered code checks under one DSL with caching, ratcheting, auto-fix, and plugin support.

**Architecture:** Check base class (inspired by phlex-lint's Rule) with pluggable context types (`:ast`, `:source`, `:tree`, `:group`, `:project`). YAML loader compiles AI check definitions to AiCheck subclasses. Runner orchestrates checks with content-hash caching and ratcheting against a committed baseline. Plugin system allows new context types, checks, and formatters.

**Tech Stack:** Ruby, rubocop-ast, RSpec, optparse

**Spec:** `docs/superpowers/specs/2026-05-25-backpressure-gem-design.md`

**Gem location:** `vendor/local_gems/backpressure/`

---

## Phase 1: Foundation — Gem Scaffold + Core Types

### Task 1: Gem Scaffold

**Files:**
- Create: `vendor/local_gems/backpressure/backpressure.gemspec`
- Create: `vendor/local_gems/backpressure/lib/backpressure.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/version.rb`
- Create: `vendor/local_gems/backpressure/Gemfile`
- Create: `vendor/local_gems/backpressure/.rspec`
- Create: `vendor/local_gems/backpressure/spec/spec_helper.rb`

- [ ] **Step 1: Create gem directory structure**

```bash
mkdir -p vendor/local_gems/backpressure/{lib/backpressure,spec,bin}
```

- [ ] **Step 2: Write version file**

Create `vendor/local_gems/backpressure/lib/backpressure/version.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  VERSION = "0.1.0"
end
```

- [ ] **Step 3: Write gemspec**

Create `vendor/local_gems/backpressure/backpressure.gemspec`:

```ruby
# frozen_string_literal: true

require_relative "lib/backpressure/version"

Gem::Specification.new do |spec|
  spec.name = "backpressure"
  spec.version = Backpressure::VERSION
  spec.authors = ["Bert Hajee"]
  spec.email = ["bert.hajee@enterprisemodules.com"]
  spec.summary = "Unified backpressure framework for Ruby codebases"
  spec.description = "Combines deterministic AST checks, component-tree checks, " \
                     "and AI prompt-based checks under one DSL with caching, " \
                     "ratcheting, auto-fix, and plugin support."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*", "bin/*", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["backpressure"]

  spec.add_dependency "rubocop-ast", "~> 1.30"

  spec.metadata["rubygems_mfa_required"] = "true"
end
```

- [ ] **Step 4: Write main entry point**

Create `vendor/local_gems/backpressure/lib/backpressure.rb`:

```ruby
# frozen_string_literal: true

require_relative "backpressure/version"

module Backpressure
  class Error < StandardError; end

  autoload :Check, "backpressure/check"
  autoload :Violation, "backpressure/violation"
  autoload :CheckRegistry, "backpressure/check_registry"
  autoload :Configuration, "backpressure/configuration"
  autoload :Runner, "backpressure/runner"

  module Contexts
    autoload :AstContext, "backpressure/contexts/ast_context"
    autoload :SourceContext, "backpressure/contexts/source_context"
  end

  module Corrections
    autoload :Replace, "backpressure/corrections/replace"
    autoload :Insert, "backpressure/corrections/insert"
    autoload :Remove, "backpressure/corrections/remove"
  end

  module Formatters
    autoload :Pretty, "backpressure/formatters/pretty"
    autoload :Json, "backpressure/formatters/json"
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def registry
      @registry ||= CheckRegistry.new
    end

    def reset!
      @configuration = nil
      @registry = nil
    end
  end
end
```

- [ ] **Step 5: Write Gemfile and RSpec config**

Create `vendor/local_gems/backpressure/Gemfile`:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rspec", "~> 3.12"
end
```

Create `vendor/local_gems/backpressure/.rspec`:

```
--require spec_helper
--format documentation
--color
```

Create `vendor/local_gems/backpressure/spec/spec_helper.rb`:

```ruby
# frozen_string_literal: true

require "backpressure"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random

  config.before do
    Backpressure.reset!
  end
end
```

- [ ] **Step 6: Install dependencies and verify**

```bash
cd vendor/local_gems/backpressure && bundle install
```

Run: `cd vendor/local_gems/backpressure && bundle exec ruby -e "require 'backpressure'; puts Backpressure::VERSION"`

Expected: `0.1.0`

- [ ] **Step 7: Commit**

```bash
git add vendor/local_gems/backpressure/
git commit -m "feat(backpressure): scaffold gem with gemspec, entry point, and RSpec setup"
```

---

### Task 2: Violation

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/violation.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/violation_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/violation_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::Violation do
  subject(:violation) do
    described_class.new(
      check_name: "NoDirectAR",
      category: "Architecture",
      severity: :warning,
      message: "Use a service object",
      file: "app/controllers/foo.rb",
      line: 42,
      column: 5,
      auto_correctable: false
    )
  end

  it "stores all attributes" do
    expect(violation.check_name).to eq("NoDirectAR")
    expect(violation.category).to eq("Architecture")
    expect(violation.severity).to eq(:warning)
    expect(violation.message).to eq("Use a service object")
    expect(violation.file).to eq("app/controllers/foo.rb")
    expect(violation.line).to eq(42)
    expect(violation.column).to eq(5)
    expect(violation.auto_correctable).to be false
  end

  it "has a location string" do
    expect(violation.location).to eq("app/controllers/foo.rb:42:5")
  end

  it "defaults column to 0" do
    v = described_class.new(
      check_name: "Test", message: "msg",
      file: "foo.rb", line: 1
    )
    expect(v.column).to eq(0)
  end

  it "defaults severity to :warning" do
    v = described_class.new(
      check_name: "Test", message: "msg",
      file: "foo.rb", line: 1
    )
    expect(v.severity).to eq(:warning)
  end

  it "is sortable by file then line" do
    v1 = described_class.new(check_name: "A", message: "m", file: "b.rb", line: 10)
    v2 = described_class.new(check_name: "A", message: "m", file: "a.rb", line: 5)
    v3 = described_class.new(check_name: "A", message: "m", file: "a.rb", line: 1)

    expect([v1, v2, v3].sort).to eq([v3, v2, v1])
  end

  describe "#identity" do
    it "returns a stable hash for ratcheting comparison" do
      expect(violation.identity).to eq("NoDirectAR:app/controllers/foo.rb:42")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/violation_spec.rb`

Expected: FAIL — `uninitialized constant Backpressure::Violation`

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/violation.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  class Violation
    attr_reader :check_name, :category, :severity, :message,
                :file, :line, :column, :auto_correctable, :correction, :source_node

    def initialize(check_name:, message:, file:, line:, column: 0, category: nil,
                   severity: :warning, auto_correctable: false, correction: nil, source_node: nil)
      @check_name = check_name
      @category = category
      @severity = severity
      @message = message
      @file = file
      @line = line
      @column = column
      @auto_correctable = auto_correctable
      @correction = correction
      @source_node = source_node
    end

    def location
      "#{file}:#{line}:#{column}"
    end

    def identity
      "#{check_name}:#{file}:#{line}"
    end

    def <=>(other)
      [file, line, column] <=> [other.file, other.line, other.column]
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/violation_spec.rb`

Expected: All examples pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/violation.rb vendor/local_gems/backpressure/spec/backpressure/violation_spec.rb
git commit -m "feat(backpressure): add Violation value object"
```

---

### Task 3: Check Base Class

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/check.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/check_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/check_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::Check do
  let(:test_check_class) do
    Class.new(described_class) do
      category "Architecture"
      severity :error
      files "app/controllers/**/*.rb"
      requires :ast

      def self.name
        "NoDirectAR"
      end

      def check(context)
        violation(context.source_node_stub, "Found direct AR")
      end
    end
  end

  describe "class-level DSL" do
    it "sets category" do
      expect(test_check_class.check_category).to eq("Architecture")
    end

    it "sets severity" do
      expect(test_check_class.check_severity).to eq(:error)
    end

    it "sets file glob" do
      expect(test_check_class.file_glob).to eq("app/controllers/**/*.rb")
    end

    it "sets required contexts" do
      expect(test_check_class.required_contexts).to eq([:ast])
    end

    it "defaults severity to :warning" do
      klass = Class.new(described_class) do
        def self.name; "DefaultCheck"; end
      end
      expect(klass.check_severity).to eq(:warning)
    end

    it "defaults ratchet to :strict" do
      expect(test_check_class.ratchet_mode).to eq(:strict)
    end

    it "supports multiple requires" do
      klass = Class.new(described_class) do
        requires :ast, :project
        def self.name; "Multi"; end
      end
      expect(klass.required_contexts).to eq([:ast, :project])
    end
  end

  describe "instance behavior" do
    let(:check) { test_check_class.new }

    it "collects violations" do
      node_stub = double("node", loc: double(line: 10, column: 5))
      allow(node_stub).to receive(:is_a?).with(RuboCop::AST::Node).and_return(true)

      context_stub = double("context", file_path: "app/controllers/foo.rb", source_node_stub: node_stub)
      check.run(context_stub)

      expect(check.violations.size).to eq(1)
      v = check.violations.first
      expect(v.message).to eq("Found direct AR")
      expect(v.check_name).to eq("NoDirectAR")
      expect(v.severity).to eq(:error)
      expect(v.file).to eq("app/controllers/foo.rb")
      expect(v.line).to eq(10)
    end

    it "supports skip" do
      skip_check_class = Class.new(described_class) do
        def self.name; "SkipCheck"; end
        def check(context)
          skip("Not applicable")
        end
      end

      check = skip_check_class.new
      context_stub = double("context", file_path: "foo.rb")
      check.run(context_stub)

      expect(check.violations).to be_empty
      expect(check.skipped?).to be true
      expect(check.skip_reason).to eq("Not applicable")
    end
  end

  describe ".check_name" do
    it "returns the class name without module prefix" do
      expect(test_check_class.check_name).to eq("NoDirectAR")
    end
  end

  describe ".matches_file?" do
    it "returns true for files matching the glob" do
      expect(test_check_class.matches_file?("app/controllers/users_controller.rb")).to be true
    end

    it "returns false for non-matching files" do
      expect(test_check_class.matches_file?("app/models/user.rb")).to be false
    end

    it "matches all files when no glob is set" do
      klass = Class.new(described_class) do
        def self.name; "AllFiles"; end
      end
      expect(klass.matches_file?("anything.rb")).to be true
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/check_spec.rb`

Expected: FAIL — `uninitialized constant Backpressure::Check`

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/check.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  class Check
    class SkipSignal < StandardError; end

    attr_reader :violations, :skip_reason

    class << self
      def category(value = nil)
        if value
          @check_category = value
        else
          @check_category
        end
      end

      def check_category
        @check_category || (superclass.respond_to?(:check_category) ? superclass.check_category : nil)
      end

      def severity(value = nil)
        if value
          @check_severity = value
        else
          @check_severity
        end
      end

      def check_severity
        @check_severity || (superclass.respond_to?(:check_severity) ? superclass.check_severity : :warning)
      end

      def files(glob = nil)
        if glob
          @file_glob = glob
        else
          @file_glob
        end
      end

      def file_glob
        @file_glob || (superclass.respond_to?(:file_glob) ? superclass.file_glob : nil)
      end

      def requires(*contexts)
        if contexts.any?
          @required_contexts = contexts
        else
          @required_contexts
        end
      end

      def required_contexts
        @required_contexts || (superclass.respond_to?(:required_contexts) ? superclass.required_contexts : [:source])
      end

      def ratchet(mode = nil)
        if mode
          @ratchet_mode = mode
        else
          @ratchet_mode
        end
      end

      def ratchet_mode
        return @ratchet_mode if defined?(@ratchet_mode)
        superclass.respond_to?(:ratchet_mode) ? superclass.ratchet_mode : :strict
      end

      def compilable(value = true)
        @compilable = value
      end

      def compilable?
        @compilable || false
      end

      def check_name
        name&.split("::")&.last || "UnnamedCheck"
      end

      def matches_file?(path)
        return true unless file_glob
        File.fnmatch(file_glob, path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
      end
    end

    def initialize
      @violations = []
      @skipped = false
      @skip_reason = nil
    end

    def run(context)
      @context = context
      check(context)
    rescue SkipSignal
      # handled in skip()
    end

    def check(context)
      raise NotImplementedError, "#{self.class.name} must implement #check"
    end

    def skipped?
      @skipped
    end

    private

    def violation(node, message, auto_correctable: false, correction: nil)
      file = @context.file_path
      line, column = extract_location(node)

      @violations << Violation.new(
        check_name: self.class.check_name,
        category: self.class.check_category,
        severity: self.class.check_severity,
        message: message,
        file: file,
        line: line,
        column: column,
        auto_correctable: auto_correctable,
        correction: correction,
        source_node: node
      )
    end

    def skip(reason)
      @skipped = true
      @skip_reason = reason
      raise SkipSignal
    end

    def extract_location(node)
      if node.respond_to?(:loc) && node.loc.respond_to?(:line)
        [node.loc.line, node.loc.respond_to?(:column) ? node.loc.column : 0]
      elsif node.respond_to?(:line)
        [node.line, node.respond_to?(:column) ? node.column : 0]
      else
        [0, 0]
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/check_spec.rb`

Expected: All examples pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/check.rb vendor/local_gems/backpressure/spec/backpressure/check_spec.rb
git commit -m "feat(backpressure): add Check base class with DSL"
```

---

### Task 4: Source Context

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/contexts/source_context.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/contexts/source_context_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/contexts/source_context_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::Contexts::SourceContext do
  let(:source) { "class Foo\n  def bar\n    42\n  end\nend\n" }
  let(:file_path) { "app/models/foo.rb" }
  subject(:context) { described_class.new(source: source, file_path: file_path) }

  it "exposes the raw source" do
    expect(context.source).to eq(source)
  end

  it "exposes the file path" do
    expect(context.file_path).to eq(file_path)
  end

  it "provides lines" do
    expect(context.lines).to eq(["class Foo", "  def bar", "    42", "  end", "end", ""])
  end

  it "provides line count" do
    expect(context.line_count).to eq(5)
  end

  it "provides a line lookup by number (1-indexed)" do
    expect(context.line(2)).to eq("  def bar")
  end

  describe ".from_file" do
    it "reads a file and creates the context" do
      tmpfile = Tempfile.new(["test", ".rb"])
      tmpfile.write(source)
      tmpfile.close

      ctx = described_class.from_file(tmpfile.path)
      expect(ctx.source).to eq(source)
      expect(ctx.file_path).to eq(tmpfile.path)
    ensure
      tmpfile.unlink
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/contexts/source_context_spec.rb`

Expected: FAIL — `uninitialized constant`

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/contexts/source_context.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module Contexts
    class SourceContext
      attr_reader :source, :file_path

      def initialize(source:, file_path:)
        @source = source
        @file_path = file_path
      end

      def lines
        @lines ||= source.split("\n", -1)
      end

      def line_count
        lines.reject(&:empty?).size
      end

      def line(number)
        lines[number - 1]
      end

      def self.from_file(path)
        new(source: File.read(path), file_path: path)
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/contexts/source_context_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/contexts/source_context.rb vendor/local_gems/backpressure/spec/backpressure/contexts/source_context_spec.rb
git commit -m "feat(backpressure): add SourceContext"
```

---

### Task 5: AST Context

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/contexts/ast_context.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/contexts/ast_context_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/contexts/ast_context_spec.rb`:

```ruby
# frozen_string_literal: true

require "rubocop-ast"

RSpec.describe Backpressure::Contexts::AstContext do
  let(:source) do
    <<~RUBY
      class UsersController
        def index
          User.where(active: true)
        end
      end
    RUBY
  end
  let(:file_path) { "app/controllers/users_controller.rb" }
  subject(:context) { described_class.new(source: source, file_path: file_path) }

  it "exposes the file path" do
    expect(context.file_path).to eq(file_path)
  end

  it "exposes the source" do
    expect(context.source).to eq(source)
  end

  it "parses the AST" do
    expect(context.ast).to be_a(RuboCop::AST::Node)
    expect(context.ast.type).to eq(:class)
  end

  it "provides each_node for traversal" do
    send_nodes = []
    context.ast.each_node(:send) do |node|
      send_nodes << node.method_name
    end

    expect(send_nodes).to include(:where)
  end

  describe ".from_file" do
    it "reads and parses a file" do
      tmpfile = Tempfile.new(["test", ".rb"])
      tmpfile.write(source)
      tmpfile.close

      ctx = described_class.from_file(tmpfile.path)
      expect(ctx.ast.type).to eq(:class)
    ensure
      tmpfile.unlink
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/contexts/ast_context_spec.rb`

Expected: FAIL — `uninitialized constant`

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/contexts/ast_context.rb`:

```ruby
# frozen_string_literal: true

require "rubocop-ast"

module Backpressure
  module Contexts
    class AstContext
      attr_reader :source, :file_path

      def initialize(source:, file_path:)
        @source = source
        @file_path = file_path
      end

      def ast
        @ast ||= parse(source)
      end

      def processed_source
        @processed_source ||= RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
      end

      def self.from_file(path)
        new(source: File.read(path), file_path: path)
      end

      private

      def parse(code)
        processed_source.ast
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/contexts/ast_context_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/contexts/ast_context.rb vendor/local_gems/backpressure/spec/backpressure/contexts/ast_context_spec.rb
git commit -m "feat(backpressure): add AstContext backed by rubocop-ast"
```

---

### Task 6: Check Registry

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/check_registry.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/check_registry_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/check_registry_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::CheckRegistry do
  subject(:registry) { described_class.new }

  let(:check_a) do
    Class.new(Backpressure::Check) do
      category "Architecture"
      files "app/controllers/**/*.rb"
      def self.name; "CheckA"; end
      def check(context); end
    end
  end

  let(:check_b) do
    Class.new(Backpressure::Check) do
      category "AI/Prompts"
      files "app/ai/**/*.rb"
      def self.name; "CheckB"; end
      def check(context); end
    end
  end

  describe "#register" do
    it "adds a check class" do
      registry.register(check_a)
      expect(registry.all).to eq([check_a])
    end

    it "prevents duplicate registration" do
      registry.register(check_a)
      registry.register(check_a)
      expect(registry.all.size).to eq(1)
    end
  end

  describe "#for_file" do
    before do
      registry.register(check_a)
      registry.register(check_b)
    end

    it "returns checks matching a file path" do
      matches = registry.for_file("app/controllers/users_controller.rb")
      expect(matches).to eq([check_a])
    end

    it "returns empty for non-matching files" do
      matches = registry.for_file("db/migrate/001.rb")
      expect(matches).to be_empty
    end
  end

  describe "#by_name" do
    before { registry.register(check_a) }

    it "finds a check by name" do
      expect(registry.by_name("CheckA")).to eq(check_a)
    end

    it "returns nil for unknown name" do
      expect(registry.by_name("Unknown")).to be_nil
    end
  end

  describe "#by_category" do
    before do
      registry.register(check_a)
      registry.register(check_b)
    end

    it "filters by category" do
      expect(registry.by_category("Architecture")).to eq([check_a])
    end

    it "filters by category prefix" do
      expect(registry.by_category("AI")).to eq([check_b])
    end
  end

  describe "#load_from" do
    it "loads check files from a directory" do
      dir = Dir.mktmpdir
      File.write(File.join(dir, "sample_check.rb"), <<~RUBY)
        class SampleCheck < Backpressure::Check
          category "Test"
          def check(context); end
        end
      RUBY

      registry.load_from(dir)
      expect(registry.by_name("SampleCheck")).not_to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/check_registry_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/check_registry.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  class CheckRegistry
    def initialize
      @checks = []
    end

    def register(check_class)
      @checks << check_class unless @checks.include?(check_class)
    end

    def all
      @checks.dup
    end

    def for_file(path)
      @checks.select { |c| c.matches_file?(path) }
    end

    def by_name(name)
      @checks.find { |c| c.check_name == name }
    end

    def by_category(prefix)
      @checks.select { |c| c.check_category&.start_with?(prefix) }
    end

    def load_from(directory)
      Dir.glob(File.join(directory, "**", "*.rb")).sort.each do |file|
        checks_before = Backpressure::Check.subclasses.dup
        require file
        new_checks = Backpressure::Check.subclasses - checks_before
        new_checks.each { |c| register(c) }
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/check_registry_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/check_registry.rb vendor/local_gems/backpressure/spec/backpressure/check_registry_spec.rb
git commit -m "feat(backpressure): add CheckRegistry with file matching and category filtering"
```

---

### Task 7: Configuration

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/configuration.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/configuration_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/configuration_spec.rb`:

```ruby
# frozen_string_literal: true

require "yaml"
require "tempfile"

RSpec.describe Backpressure::Configuration do
  subject(:config) { described_class.new }

  it "has default check_paths" do
    expect(config.check_paths).to eq(["checks/"])
  end

  it "has default include patterns" do
    expect(config.include_patterns).to eq(["**/*.rb"])
  end

  it "has default exclude patterns" do
    expect(config.exclude_patterns).to eq([])
  end

  it "has empty ai config by default" do
    expect(config.ai_config).to eq({})
  end

  it "has default cache settings" do
    expect(config.cache_enabled).to be true
    expect(config.cache_dir).to eq(".backpressure_cache")
  end

  it "has default ratchet settings" do
    expect(config.baseline_file).to eq("backpressure_baseline.yml")
    expect(config.anti_tamper).to be true
  end

  it "has default format" do
    expect(config.format).to eq(:pretty)
  end

  describe ".from_file" do
    it "loads settings from YAML" do
      yaml = {
        "check_paths" => ["custom_checks/", "ai_checks/"],
        "include" => ["app/**/*.rb"],
        "exclude" => ["vendor/**"],
        "format" => "json",
        "ai" => {
          "default_provider" => "gemini",
          "tiers" => { "cheap" => "gemini-2.0-flash" }
        },
        "cache" => { "enabled" => false, "dir" => "tmp/cache" },
        "ratchet" => { "baseline_file" => "custom_baseline.yml", "anti_tamper" => false },
        "checks" => {
          "NoDirectAR" => { "enabled" => false, "severity" => "error" }
        }
      }

      tmpfile = Tempfile.new(["backpressure", ".yml"])
      tmpfile.write(yaml.to_yaml)
      tmpfile.close

      config = described_class.from_file(tmpfile.path)

      expect(config.check_paths).to eq(["custom_checks/", "ai_checks/"])
      expect(config.include_patterns).to eq(["app/**/*.rb"])
      expect(config.exclude_patterns).to eq(["vendor/**"])
      expect(config.format).to eq(:json)
      expect(config.ai_config["default_provider"]).to eq("gemini")
      expect(config.cache_enabled).to be false
      expect(config.cache_dir).to eq("tmp/cache")
      expect(config.baseline_file).to eq("custom_baseline.yml")
      expect(config.anti_tamper).to be false
      expect(config.check_overrides("NoDirectAR")).to eq({ "enabled" => false, "severity" => "error" })
    ensure
      tmpfile.unlink
    end
  end

  describe "#check_enabled?" do
    it "returns true by default" do
      expect(config.check_enabled?("AnyCheck")).to be true
    end

    it "returns false when disabled in overrides" do
      config = described_class.from_hash("checks" => { "NoDirectAR" => { "enabled" => false } })
      expect(config.check_enabled?("NoDirectAR")).to be false
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/configuration_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/configuration.rb`:

```ruby
# frozen_string_literal: true

require "yaml"

module Backpressure
  class Configuration
    attr_reader :check_paths, :include_patterns, :exclude_patterns,
                :ai_config, :cache_enabled, :cache_dir,
                :baseline_file, :anti_tamper, :format, :plugins

    def initialize
      @check_paths = ["checks/"]
      @include_patterns = ["**/*.rb"]
      @exclude_patterns = []
      @ai_config = {}
      @cache_enabled = true
      @cache_dir = ".backpressure_cache"
      @baseline_file = "backpressure_baseline.yml"
      @anti_tamper = true
      @format = :pretty
      @plugins = []
      @check_overrides = {}
    end

    def self.from_file(path)
      data = YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
      from_hash(data)
    end

    def self.from_hash(data)
      config = new
      config.apply(data)
      config
    end

    def apply(data)
      @check_paths = data["check_paths"] if data["check_paths"]
      @include_patterns = data["include"] if data["include"]
      @exclude_patterns = data["exclude"] if data["exclude"]
      @format = data["format"]&.to_sym if data["format"]
      @ai_config = data["ai"] if data["ai"]
      @plugins = data["plugins"] || []

      if data["cache"]
        @cache_enabled = data["cache"].fetch("enabled", @cache_enabled)
        @cache_dir = data["cache"].fetch("dir", @cache_dir)
      end

      if data["ratchet"]
        @baseline_file = data["ratchet"].fetch("baseline_file", @baseline_file)
        @anti_tamper = data["ratchet"].fetch("anti_tamper", @anti_tamper)
      end

      @check_overrides = data["checks"] || {}
    end

    def check_overrides(name)
      @check_overrides[name] || {}
    end

    def check_enabled?(name)
      overrides = check_overrides(name)
      overrides.fetch("enabled", true)
    end

    def resolve_tier(tier_name)
      tiers = ai_config.dig("tiers") || {}
      tiers[tier_name.to_s] || tier_name.to_s
    end

    def ai_provider
      ai_config["default_provider"]
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/configuration_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/configuration.rb vendor/local_gems/backpressure/spec/backpressure/configuration_spec.rb
git commit -m "feat(backpressure): add Configuration with YAML loading and check overrides"
```

---

### Task 8: Pretty Formatter

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/formatters/base.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/formatters/pretty.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/formatters/pretty_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/formatters/pretty_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::Formatters::Pretty do
  subject(:formatter) { described_class.new }

  let(:violations) do
    [
      Backpressure::Violation.new(
        check_name: "NoDirectAR",
        category: "Architecture",
        severity: :error,
        message: "Use a service object",
        file: "app/controllers/foo.rb",
        line: 42,
        column: 5,
        auto_correctable: true
      ),
      Backpressure::Violation.new(
        check_name: "NoDirectAR",
        category: "Architecture",
        severity: :warning,
        message: "Use a service object",
        file: "app/controllers/bar.rb",
        line: 10,
        column: 3
      )
    ]
  end

  describe "#format" do
    it "includes file path and line" do
      output = formatter.format(violations)
      expect(output).to include("app/controllers/foo.rb:42:5")
    end

    it "includes the check name" do
      output = formatter.format(violations)
      expect(output).to include("NoDirectAR")
    end

    it "includes the message" do
      output = formatter.format(violations)
      expect(output).to include("Use a service object")
    end

    it "shows auto-correctable marker" do
      output = formatter.format(violations)
      expect(output).to include("auto-correctable")
    end

    it "includes a summary line" do
      output = formatter.format(violations)
      expect(output).to include("2 violation(s)")
    end

    it "returns clean output for zero violations" do
      output = formatter.format([])
      expect(output).to include("No violations")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/formatters/pretty_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/formatters/base.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module Formatters
    class Base
      def format(violations)
        raise NotImplementedError
      end
    end
  end
end
```

Create `vendor/local_gems/backpressure/lib/backpressure/formatters/pretty.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module Formatters
    class Pretty < Base
      SEVERITY_COLORS = {
        error: "\e[31m",
        warning: "\e[33m",
        info: "\e[36m"
      }.freeze
      RESET = "\e[0m"

      def format(violations)
        return "No violations found.\n" if violations.empty?

        lines = violations.sort.map { |v| format_violation(v) }
        auto_count = violations.count(&:auto_correctable)

        summary = "\nbackpressure: #{violations.size} violation(s) found."
        summary += "\n  #{auto_count} auto-correctable (use backpressure fix)" if auto_count > 0
        manual = violations.size - auto_count
        summary += "\n  #{manual} require manual fixes" if manual > 0

        (lines + [summary, ""]).join("\n")
      end

      private

      def format_violation(v)
        color = SEVERITY_COLORS.fetch(v.severity, "")
        parts = [
          "#{v.location}: #{color}[#{v.check_name}]#{RESET} #{v.message}"
        ]
        parts << "  auto-correctable" if v.auto_correctable
        parts.join("\n")
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/formatters/pretty_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/formatters/ vendor/local_gems/backpressure/spec/backpressure/formatters/
git commit -m "feat(backpressure): add Pretty formatter with severity coloring"
```

---

### Task 9: Runner

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/runner.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/runner_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/runner_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::Runner do
  let(:config) { Backpressure::Configuration.new }
  let(:registry) { Backpressure::CheckRegistry.new }
  subject(:runner) { described_class.new(config: config, registry: registry) }

  let(:passing_check) do
    Class.new(Backpressure::Check) do
      files "**/*.rb"
      requires :source
      def self.name; "PassingCheck"; end
      def check(context); end
    end
  end

  let(:failing_check) do
    Class.new(Backpressure::Check) do
      files "**/*.rb"
      requires :source
      severity :error
      def self.name; "FailingCheck"; end
      def check(context)
        violation(OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0)), "Something is wrong")
      end
    end
  end

  before do
    registry.register(passing_check)
    registry.register(failing_check)
  end

  describe "#run" do
    it "returns results with violations" do
      tmpfile = Tempfile.new(["test", ".rb"])
      tmpfile.write("class Foo; end")
      tmpfile.close

      result = runner.run(files: [tmpfile.path])

      expect(result.violations.size).to eq(1)
      expect(result.violations.first.check_name).to eq("FailingCheck")
    ensure
      tmpfile.unlink
    end

    it "filters by --only check name" do
      tmpfile = Tempfile.new(["test", ".rb"])
      tmpfile.write("class Foo; end")
      tmpfile.close

      result = runner.run(files: [tmpfile.path], only: ["PassingCheck"])
      expect(result.violations).to be_empty
    ensure
      tmpfile.unlink
    end

    it "skips disabled checks" do
      config = Backpressure::Configuration.from_hash(
        "checks" => { "FailingCheck" => { "enabled" => false } }
      )
      runner = described_class.new(config: config, registry: registry)

      tmpfile = Tempfile.new(["test", ".rb"])
      tmpfile.write("class Foo; end")
      tmpfile.close

      result = runner.run(files: [tmpfile.path])
      expect(result.violations).to be_empty
    ensure
      tmpfile.unlink
    end
  end

  describe "Backpressure::Runner::Result" do
    it "reports success when no error violations" do
      result = described_class::Result.new(violations: [], skipped: [])
      expect(result.success?).to be true
    end

    it "reports failure when error violations exist" do
      v = Backpressure::Violation.new(
        check_name: "X", message: "m", file: "f.rb", line: 1, severity: :error
      )
      result = described_class::Result.new(violations: [v], skipped: [])
      expect(result.success?).to be false
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/runner_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/runner.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  class Runner
    Result = Struct.new(:violations, :skipped, keyword_init: true) do
      def success?
        violations.none? { |v| v.severity == :error }
      end

      def violation_count
        violations.size
      end
    end

    def initialize(config:, registry:)
      @config = config
      @registry = registry
    end

    def run(files:, only: nil)
      all_violations = []
      all_skipped = []

      files.each do |file_path|
        checks = resolve_checks(file_path, only: only)
        source = File.read(file_path)

        checks.each do |check_class|
          context = build_context(check_class, source: source, file_path: file_path)
          instance = check_class.new
          instance.run(context)

          if instance.skipped?
            all_skipped << { check: check_class.check_name, file: file_path, reason: instance.skip_reason }
          else
            all_violations.concat(instance.violations)
          end
        end
      end

      Result.new(violations: all_violations.sort, skipped: all_skipped)
    end

    private

    def resolve_checks(file_path, only: nil)
      checks = @registry.for_file(file_path)
      checks = checks.select { |c| @config.check_enabled?(c.check_name) }
      checks = checks.select { |c| only.include?(c.check_name) } if only
      checks
    end

    def build_context(check_class, source:, file_path:)
      contexts = check_class.required_contexts
      if contexts.include?(:ast)
        Contexts::AstContext.new(source: source, file_path: file_path)
      else
        Contexts::SourceContext.new(source: source, file_path: file_path)
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/runner_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/runner.rb vendor/local_gems/backpressure/spec/backpressure/runner_spec.rb
git commit -m "feat(backpressure): add Runner with check resolution and context building"
```

---

### Task 10: CLI — check command

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/cli.rb`
- Create: `vendor/local_gems/backpressure/bin/backpressure`
- Create: `vendor/local_gems/backpressure/spec/backpressure/cli_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/cli_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::CLI do
  describe ".parse" do
    it "parses check command" do
      options = described_class.parse(["check"])
      expect(options[:command]).to eq(:check)
    end

    it "parses --only flag" do
      options = described_class.parse(["check", "--only", "NoDirectAR"])
      expect(options[:only]).to eq(["NoDirectAR"])
    end

    it "parses --format flag" do
      options = described_class.parse(["check", "--format", "json"])
      expect(options[:format]).to eq(:json)
    end

    it "parses --update-baseline flag" do
      options = described_class.parse(["check", "--update-baseline"])
      expect(options[:update_baseline]).to be true
    end

    it "parses --no-cache flag" do
      options = described_class.parse(["check", "--no-cache"])
      expect(options[:cache]).to be false
    end

    it "parses file path arguments" do
      options = described_class.parse(["check", "app/controllers/"])
      expect(options[:paths]).to eq(["app/controllers/"])
    end

    it "parses list command" do
      options = described_class.parse(["list"])
      expect(options[:command]).to eq(:list)
    end

    it "parses fix command" do
      options = described_class.parse(["fix"])
      expect(options[:command]).to eq(:fix)
    end

    it "parses --ai-fix flag on fix command" do
      options = described_class.parse(["fix", "--ai-fix"])
      expect(options[:ai_fix]).to be true
    end

    it "parses --interactive flag on fix command" do
      options = described_class.parse(["fix", "--interactive"])
      expect(options[:interactive]).to be true
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/cli_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/cli.rb`:

```ruby
# frozen_string_literal: true

require "optparse"

module Backpressure
  class CLI
    COMMANDS = %w[check fix list init cache compile].freeze

    def self.parse(argv)
      options = { command: nil, only: nil, format: nil, paths: [],
                  update_baseline: false, cache: true, ai_fix: false,
                  interactive: false, dry_run: false }

      command = argv.shift if argv.first && !argv.first.start_with?("-")
      options[:command] = command&.to_sym

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: backpressure <command> [options] [paths...]"

        opts.on("--only CHECKS", "Run specific checks (comma-separated)") do |v|
          options[:only] = v.split(",").map(&:strip)
        end

        opts.on("--format FORMAT", "Output format: pretty, json, rubocop") do |v|
          options[:format] = v.to_sym
        end

        opts.on("--update-baseline", "Update the ratchet baseline") do
          options[:update_baseline] = true
        end

        opts.on("--no-cache", "Bypass the cache") do
          options[:cache] = false
        end

        opts.on("--ai-fix", "Apply AI-suggested fixes") do
          options[:ai_fix] = true
        end

        opts.on("--interactive", "Confirm each fix interactively") do
          options[:interactive] = true
        end

        opts.on("--dry-run", "Show what would be fixed without applying") do
          options[:dry_run] = true
        end

        opts.on("-h", "--help", "Show help") do
          puts opts
          exit
        end
      end

      parser.parse!(argv)
      options[:paths] = argv unless argv.empty?
      options
    end

    def self.run(argv = ARGV)
      options = parse(argv)
      new(options).execute
    end

    def initialize(options)
      @options = options
    end

    def execute
      config = load_config
      registry = Backpressure.registry

      config.check_paths.each { |path| registry.load_from(path) if Dir.exist?(path) }

      case @options[:command]
      when :check then run_check(config, registry)
      when :list then run_list(registry)
      when :fix then run_fix(config, registry)
      when :init then run_init
      when :cache then run_cache(config)
      else
        $stderr.puts "Unknown command: #{@options[:command]}"
        exit 1
      end
    end

    private

    def load_config
      config_path = "backpressure.yml"
      if File.exist?(config_path)
        Configuration.from_file(config_path)
      else
        Configuration.new
      end
    end

    def run_check(config, registry)
      files = resolve_files(config)
      runner = Runner.new(config: config, registry: registry)
      result = runner.run(files: files, only: @options[:only])

      formatter = resolve_formatter(config)
      puts formatter.format(result.violations)

      exit(result.success? ? 0 : 1)
    end

    def run_list(registry)
      registry.all.each do |check|
        puts "#{check.check_name.ljust(40)} #{check.check_category || '-'}"
      end
    end

    def run_fix(config, registry)
      $stderr.puts "fix command not yet implemented"
      exit 1
    end

    def run_init
      if File.exist?("backpressure.yml")
        $stderr.puts "backpressure.yml already exists"
        exit 1
      end

      File.write("backpressure.yml", default_config_yaml)
      puts "Created backpressure.yml"
    end

    def run_cache(config)
      $stderr.puts "cache command not yet implemented"
      exit 1
    end

    def resolve_files(config)
      patterns = @options[:paths].empty? ? config.include_patterns : @options[:paths]
      files = patterns.flat_map { |p| Dir.glob(p) }.select { |f| File.file?(f) }.uniq
      excludes = config.exclude_patterns
      files.reject { |f| excludes.any? { |e| File.fnmatch(e, f, File::FNM_PATHNAME) } }
    end

    def resolve_formatter(config)
      format = @options[:format] || config.format
      case format
      when :json then Formatters::Json.new
      else Formatters::Pretty.new
      end
    end

    def default_config_yaml
      <<~YAML
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
      YAML
    end
  end
end
```

Create `vendor/local_gems/backpressure/bin/backpressure`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/backpressure"

Backpressure::CLI.run
```

```bash
chmod +x vendor/local_gems/backpressure/bin/backpressure
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/cli_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/cli.rb vendor/local_gems/backpressure/bin/backpressure vendor/local_gems/backpressure/spec/backpressure/cli_spec.rb
git commit -m "feat(backpressure): add CLI with check, list, fix, and init commands"
```

---

### Task 11: JSON Formatter

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/formatters/json.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/formatters/json_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/formatters/json_spec.rb`:

```ruby
# frozen_string_literal: true

require "json"

RSpec.describe Backpressure::Formatters::Json do
  subject(:formatter) { described_class.new }

  let(:violations) do
    [
      Backpressure::Violation.new(
        check_name: "NoDirectAR",
        category: "Architecture",
        severity: :error,
        message: "Use a service object",
        file: "app/controllers/foo.rb",
        line: 42,
        column: 5,
        auto_correctable: true
      )
    ]
  end

  describe "#format" do
    it "returns valid JSON" do
      output = formatter.format(violations)
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
    end

    it "includes all violation fields" do
      output = formatter.format(violations)
      parsed = JSON.parse(output)
      v = parsed.first

      expect(v["check_name"]).to eq("NoDirectAR")
      expect(v["category"]).to eq("Architecture")
      expect(v["severity"]).to eq("error")
      expect(v["message"]).to eq("Use a service object")
      expect(v["file"]).to eq("app/controllers/foo.rb")
      expect(v["line"]).to eq(42)
      expect(v["column"]).to eq(5)
      expect(v["auto_correctable"]).to be true
    end

    it "returns empty array for no violations" do
      output = formatter.format([])
      expect(JSON.parse(output)).to eq([])
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/formatters/json_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/formatters/json.rb`:

```ruby
# frozen_string_literal: true

require "json"

module Backpressure
  module Formatters
    class Json < Base
      def format(violations)
        JSON.pretty_generate(violations.sort.map { |v| serialize(v) })
      end

      private

      def serialize(v)
        {
          check_name: v.check_name,
          category: v.category,
          severity: v.severity.to_s,
          message: v.message,
          file: v.file,
          line: v.line,
          column: v.column,
          auto_correctable: v.auto_correctable
        }
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/formatters/json_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/formatters/json.rb vendor/local_gems/backpressure/spec/backpressure/formatters/json_spec.rb
git commit -m "feat(backpressure): add JSON formatter"
```

---

### Task 12: End-to-End Integration Test (Phase 1)

**Files:**
- Create: `vendor/local_gems/backpressure/spec/integration/check_flow_spec.rb`

- [ ] **Step 1: Write the integration test**

Create `vendor/local_gems/backpressure/spec/integration/check_flow_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe "End-to-end check flow" do
  let(:project_dir) { Dir.mktmpdir("bp_test") }

  after { FileUtils.remove_entry(project_dir) }

  it "runs an AST check against a file and reports violations" do
    checks_dir = File.join(project_dir, "checks")
    FileUtils.mkdir_p(checks_dir)

    File.write(File.join(checks_dir, "no_puts.rb"), <<~RUBY)
      class NoPuts < Backpressure::Check
        category "Style"
        severity :warning
        files "**/*.rb"
        requires :ast

        def check(context)
          context.ast.each_node(:send) do |node|
            if node.method_name == :puts
              violation(node, "Avoid using puts in production code")
            end
          end
        end
      end
    RUBY

    target = File.join(project_dir, "app.rb")
    File.write(target, <<~RUBY)
      class App
        def run
          puts "hello"
          do_work
          puts "done"
        end
      end
    RUBY

    registry = Backpressure::CheckRegistry.new
    registry.load_from(checks_dir)

    config = Backpressure::Configuration.new
    runner = Backpressure::Runner.new(config: config, registry: registry)
    result = runner.run(files: [target])

    expect(result.violations.size).to eq(2)
    expect(result.violations.map(&:message)).to all(eq("Avoid using puts in production code"))
    expect(result.violations.map(&:line)).to contain_exactly(3, 5)

    pretty = Backpressure::Formatters::Pretty.new.format(result.violations)
    expect(pretty).to include("NoPuts")
    expect(pretty).to include("2 violation(s)")

    json_output = Backpressure::Formatters::Json.new.format(result.violations)
    parsed = JSON.parse(json_output)
    expect(parsed.size).to eq(2)
  end

  it "runs a source check against a file" do
    checks_dir = File.join(project_dir, "checks")
    FileUtils.mkdir_p(checks_dir)

    File.write(File.join(checks_dir, "no_todo.rb"), <<~RUBY)
      class NoTodo < Backpressure::Check
        category "Style"
        files "**/*.rb"
        requires :source

        def check(context)
          context.lines.each_with_index do |line, idx|
            if line.match?(/TODO/i)
              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Remove TODO comment")
            end
          end
        end
      end
    RUBY

    target = File.join(project_dir, "app.rb")
    File.write(target, "# TODO: fix this\ncode\n# TODO: and this\n")

    registry = Backpressure::CheckRegistry.new
    registry.load_from(checks_dir)

    config = Backpressure::Configuration.new
    runner = Backpressure::Runner.new(config: config, registry: registry)
    result = runner.run(files: [target])

    expect(result.violations.size).to eq(2)
    expect(result.violations.map(&:line)).to contain_exactly(1, 3)
  end
end
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/integration/check_flow_spec.rb`

Expected: All pass (this validates the end-to-end wiring)

- [ ] **Step 3: Run full test suite**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec`

Expected: All specs pass

- [ ] **Step 4: Commit**

```bash
git add vendor/local_gems/backpressure/spec/integration/
git commit -m "test(backpressure): add end-to-end integration test for check flow"
```

---

## Phase 2: Ratcheting & Caching

### Task 13: Baseline

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/baseline.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/baseline_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/baseline_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"
require "yaml"

RSpec.describe Backpressure::Baseline do
  let(:tmpdir) { Dir.mktmpdir("bp_baseline") }
  let(:baseline_path) { File.join(tmpdir, "backpressure_baseline.yml") }

  after { FileUtils.remove_entry(tmpdir) }

  let(:violations) do
    [
      Backpressure::Violation.new(check_name: "CheckA", message: "m1", file: "a.rb", line: 10),
      Backpressure::Violation.new(check_name: "CheckA", message: "m2", file: "b.rb", line: 20),
      Backpressure::Violation.new(check_name: "CheckB", message: "m3", file: "c.rb", line: 5)
    ]
  end

  describe ".write" do
    it "writes a baseline file from violations" do
      described_class.write(violations, path: baseline_path)
      expect(File.exist?(baseline_path)).to be true

      data = YAML.safe_load_file(baseline_path)
      expect(data["checks"]["CheckA"]["count"]).to eq(2)
      expect(data["checks"]["CheckB"]["count"]).to eq(1)
      expect(data["checks"]["CheckA"]["files"]).to contain_exactly("a.rb:10", "b.rb:20")
    end
  end

  describe ".load" do
    it "loads an existing baseline" do
      described_class.write(violations, path: baseline_path)
      baseline = described_class.load(baseline_path)

      expect(baseline.count_for("CheckA")).to eq(2)
      expect(baseline.count_for("CheckB")).to eq(1)
      expect(baseline.count_for("Unknown")).to eq(0)
    end

    it "returns empty baseline when file doesn't exist" do
      baseline = described_class.load(baseline_path)
      expect(baseline.count_for("CheckA")).to eq(0)
      expect(baseline.empty?).to be true
    end
  end

  describe "#new_violations" do
    it "identifies violations not in baseline" do
      described_class.write(violations, path: baseline_path)
      baseline = described_class.load(baseline_path)

      current = violations + [
        Backpressure::Violation.new(check_name: "CheckA", message: "m4", file: "d.rb", line: 30)
      ]

      new_ones = baseline.new_violations(current)
      expect(new_ones.size).to eq(1)
      expect(new_ones.first.file).to eq("d.rb")
    end

    it "returns all violations when no baseline exists" do
      baseline = described_class.load(baseline_path)
      new_ones = baseline.new_violations(violations)
      expect(new_ones.size).to eq(3)
    end
  end

  describe "#tampered?" do
    it "detects when baseline counts increased without update" do
      described_class.write(violations, path: baseline_path)
      baseline = described_class.load(baseline_path)

      fewer_violations = [violations.first]
      expect(baseline.tampered?(fewer_violations)).to be false

      data = YAML.safe_load_file(baseline_path)
      data["checks"]["CheckA"]["count"] = 100
      File.write(baseline_path, data.to_yaml)
      tampered_baseline = described_class.load(baseline_path)

      expect(tampered_baseline.tampered?(violations)).to be true
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/baseline_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/baseline.rb`:

```ruby
# frozen_string_literal: true

require "yaml"

module Backpressure
  class Baseline
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def self.write(violations, path:)
      checks = violations.group_by(&:check_name).transform_values do |vs|
        {
          "count" => vs.size,
          "files" => vs.sort.map(&:identity).map { |id| id.split(":", 2).last }
        }
      end

      content = {
        "generated_at" => Time.now.utc.iso8601,
        "checks" => checks
      }

      File.write(path, content.to_yaml)
    end

    def self.load(path)
      if File.exist?(path)
        data = YAML.safe_load_file(path) || {}
        new(data)
      else
        new({})
      end
    end

    def empty?
      checks.empty?
    end

    def count_for(check_name)
      checks.dig(check_name, "count") || 0
    end

    def files_for(check_name)
      checks.dig(check_name, "files") || []
    end

    def new_violations(current_violations)
      return current_violations if empty?

      current_violations.reject do |v|
        identity_suffix = v.identity.split(":", 2).last
        files_for(v.check_name).include?(identity_suffix)
      end
    end

    def tampered?(current_violations)
      return false if empty?

      current_by_check = current_violations.group_by(&:check_name)

      checks.any? do |check_name, baseline_data|
        actual = current_by_check.fetch(check_name, []).size
        baseline_data["count"] > actual
      end
    end

    private

    def checks
      @data.fetch("checks", {})
    end
  end
end
```

Add autoload to `lib/backpressure.rb`:

Add `autoload :Baseline, "backpressure/baseline"` to the Backpressure module.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/baseline_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/baseline.rb vendor/local_gems/backpressure/spec/backpressure/baseline_spec.rb vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add Baseline for ratcheting with anti-tamper detection"
```

---

### Task 14: Ratchet (Runner Integration)

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/ratchet.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/ratchet_spec.rb`
- Modify: `vendor/local_gems/backpressure/lib/backpressure/runner.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/ratchet_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::Ratchet do
  let(:tmpdir) { Dir.mktmpdir("bp_ratchet") }
  let(:baseline_path) { File.join(tmpdir, "baseline.yml") }

  after { FileUtils.remove_entry(tmpdir) }

  let(:baseline_violations) do
    [
      Backpressure::Violation.new(check_name: "CheckA", message: "m", file: "a.rb", line: 10),
      Backpressure::Violation.new(check_name: "CheckA", message: "m", file: "b.rb", line: 20)
    ]
  end

  describe "#evaluate" do
    it "passes when violations are within baseline" do
      Backpressure::Baseline.write(baseline_violations, path: baseline_path)
      ratchet = described_class.new(baseline_path: baseline_path, anti_tamper: true)

      result = ratchet.evaluate(baseline_violations)
      expect(result.pass?).to be true
      expect(result.new_violations).to be_empty
    end

    it "fails when new violations appear" do
      Backpressure::Baseline.write(baseline_violations, path: baseline_path)
      ratchet = described_class.new(baseline_path: baseline_path, anti_tamper: true)

      current = baseline_violations + [
        Backpressure::Violation.new(check_name: "CheckA", message: "m", file: "c.rb", line: 30)
      ]

      result = ratchet.evaluate(current)
      expect(result.pass?).to be false
      expect(result.new_violations.size).to eq(1)
    end

    it "passes when no baseline exists (first run)" do
      ratchet = described_class.new(baseline_path: baseline_path, anti_tamper: true)
      result = ratchet.evaluate(baseline_violations)
      expect(result.pass?).to be true
    end

    it "fails on tampered baseline" do
      Backpressure::Baseline.write(baseline_violations, path: baseline_path)

      data = YAML.safe_load_file(baseline_path)
      data["checks"]["CheckA"]["count"] = 999
      File.write(baseline_path, data.to_yaml)

      ratchet = described_class.new(baseline_path: baseline_path, anti_tamper: true)
      result = ratchet.evaluate(baseline_violations)
      expect(result.pass?).to be false
      expect(result.tampered?).to be true
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/ratchet_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/ratchet.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  class Ratchet
    Result = Struct.new(:new_violations, :tampered, keyword_init: true) do
      def pass?
        new_violations.empty? && !tampered
      end

      def tampered?
        tampered
      end
    end

    def initialize(baseline_path:, anti_tamper: true)
      @baseline_path = baseline_path
      @anti_tamper = anti_tamper
    end

    def evaluate(violations)
      baseline = Baseline.load(@baseline_path)
      return Result.new(new_violations: [], tampered: false) if baseline.empty?

      tampered = @anti_tamper && baseline.tampered?(violations)
      new_violations = baseline.new_violations(violations)

      Result.new(new_violations: new_violations, tampered: tampered)
    end

    def update_baseline(violations)
      Baseline.write(violations, path: @baseline_path)
    end
  end
end
```

Add `autoload :Ratchet, "backpressure/ratchet"` to `lib/backpressure.rb`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/ratchet_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/ratchet.rb vendor/local_gems/backpressure/spec/backpressure/ratchet_spec.rb vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add Ratchet with anti-tamper evaluation"
```

---

### Task 15: Cache

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/cache.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/cache_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/cache_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::Cache do
  let(:cache_dir) { Dir.mktmpdir("bp_cache") }
  subject(:cache) { described_class.new(dir: cache_dir) }

  after { FileUtils.remove_entry(cache_dir) }

  describe "#fetch" do
    it "returns nil on cache miss" do
      result = cache.fetch(check_name: "CheckA", file_path: "a.rb", file_content: "code", check_version: "v1")
      expect(result).to be_nil
    end

    it "stores and retrieves results" do
      violations = [{ check_name: "CheckA", message: "bad", line: 10 }]

      cache.store(
        check_name: "CheckA", file_path: "a.rb",
        file_content: "code", check_version: "v1",
        result: violations
      )

      fetched = cache.fetch(check_name: "CheckA", file_path: "a.rb", file_content: "code", check_version: "v1")
      expect(fetched).to eq(violations)
    end

    it "misses when file content changes" do
      cache.store(
        check_name: "CheckA", file_path: "a.rb",
        file_content: "old code", check_version: "v1",
        result: []
      )

      fetched = cache.fetch(check_name: "CheckA", file_path: "a.rb", file_content: "new code", check_version: "v1")
      expect(fetched).to be_nil
    end

    it "misses when check version changes" do
      cache.store(
        check_name: "CheckA", file_path: "a.rb",
        file_content: "code", check_version: "v1",
        result: []
      )

      fetched = cache.fetch(check_name: "CheckA", file_path: "a.rb", file_content: "code", check_version: "v2")
      expect(fetched).to be_nil
    end
  end

  describe "#clear" do
    it "removes all cached data" do
      cache.store(check_name: "A", file_path: "a.rb", file_content: "c", check_version: "v", result: [])
      cache.clear
      expect(cache.fetch(check_name: "A", file_path: "a.rb", file_content: "c", check_version: "v")).to be_nil
    end
  end

  describe "#stats" do
    it "reports cache size" do
      cache.store(check_name: "A", file_path: "a.rb", file_content: "c", check_version: "v", result: [])
      cache.store(check_name: "B", file_path: "b.rb", file_content: "c", check_version: "v", result: [])
      expect(cache.stats[:entries]).to eq(2)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/cache_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/cache.rb`:

```ruby
# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"

module Backpressure
  class Cache
    def initialize(dir:)
      @dir = dir
    end

    def fetch(check_name:, file_path:, file_content:, check_version:)
      path = cache_path(check_name, file_path, file_content, check_version)
      return nil unless File.exist?(path)

      JSON.parse(File.read(path))
    end

    def store(check_name:, file_path:, file_content:, check_version:, result:)
      path = cache_path(check_name, file_path, file_content, check_version)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.generate(result))
    end

    def clear
      FileUtils.rm_rf(@dir)
    end

    def stats
      entries = Dir.glob(File.join(@dir, "**", "*.json")).size
      total_bytes = Dir.glob(File.join(@dir, "**", "*.json")).sum { |f| File.size(f) }
      { entries: entries, total_bytes: total_bytes }
    end

    private

    def cache_path(check_name, file_path, file_content, check_version)
      key = Digest::SHA256.hexdigest("#{check_version}:#{file_path}:#{file_content}")
      File.join(@dir, check_name, "#{key}.json")
    end
  end
end
```

Add `autoload :Cache, "backpressure/cache"` to `lib/backpressure.rb`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/cache_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/cache.rb vendor/local_gems/backpressure/spec/backpressure/cache_spec.rb vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add content-hash Cache with file system backend"
```

---

## Phase 3: Auto-Fix

### Task 16: Corrections (Replace, Insert, Remove)

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/correction.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/corrections/replace.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/corrections/insert.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/corrections/remove.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/corrections_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/corrections_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe "Corrections" do
  let(:source) { "  User.where(active: true)\n  User.find(1)\n  puts 'done'\n" }
  let(:lines) { source.lines }

  describe Backpressure::Corrections::Replace do
    it "replaces a line range with new content" do
      correction = described_class.new(line: 1, original: "  User.where(active: true)", replacement: "  UserService.active_users")
      result = correction.apply(source)
      expect(result).to include("UserService.active_users")
      expect(result).not_to include("User.where")
    end
  end

  describe Backpressure::Corrections::Insert do
    it "inserts text before a line" do
      correction = described_class.new(line: 1, text: "  # Fixed\n", position: :before)
      result = correction.apply(source)
      expect(result.lines.first).to eq("  # Fixed\n")
    end

    it "inserts text after a line" do
      correction = described_class.new(line: 1, text: "  # After\n", position: :after)
      result = correction.apply(source)
      expect(result.lines[1]).to eq("  # After\n")
    end
  end

  describe Backpressure::Corrections::Remove do
    it "removes a line" do
      correction = described_class.new(line: 2)
      result = correction.apply(source)
      expect(result).not_to include("User.find")
      expect(result.lines.size).to eq(2)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/corrections_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/correction.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  class Correction
    attr_reader :line

    def apply(source)
      raise NotImplementedError
    end
  end
end
```

Create `vendor/local_gems/backpressure/lib/backpressure/corrections/replace.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module Corrections
    class Replace < Correction
      attr_reader :original, :replacement

      def initialize(line:, original:, replacement:)
        @line = line
        @original = original
        @replacement = replacement
      end

      def apply(source)
        lines = source.lines
        lines[@line - 1] = lines[@line - 1].sub(original, replacement)
        lines.join
      end
    end
  end
end
```

Create `vendor/local_gems/backpressure/lib/backpressure/corrections/insert.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module Corrections
    class Insert < Correction
      attr_reader :text, :position

      def initialize(line:, text:, position: :before)
        @line = line
        @text = text
        @position = position
      end

      def apply(source)
        lines = source.lines
        idx = @line - 1
        if position == :before
          lines.insert(idx, text)
        else
          lines.insert(idx + 1, text)
        end
        lines.join
      end
    end
  end
end
```

Create `vendor/local_gems/backpressure/lib/backpressure/corrections/remove.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module Corrections
    class Remove < Correction
      def initialize(line:)
        @line = line
      end

      def apply(source)
        lines = source.lines
        lines.delete_at(@line - 1)
        lines.join
      end
    end
  end
end
```

Add autoloads to `lib/backpressure.rb` for `Correction` and the `Corrections` module.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/corrections_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/correction.rb vendor/local_gems/backpressure/lib/backpressure/corrections/ vendor/local_gems/backpressure/spec/backpressure/corrections_spec.rb vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add Replace, Insert, Remove corrections"
```

---

## Phase 4: AI Layer

### Task 17: AI Provider Interface

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/ai/provider.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/ai/provider_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/ai/provider_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::AI::Provider do
  describe ".for" do
    it "returns a provider instance by name" do
      provider = described_class.for(:test, config: {})
      expect(provider).to be_a(Backpressure::AI::Provider)
    end

    it "raises for unknown provider" do
      expect { described_class.for(:unknown_xyz, config: {}) }
        .to raise_error(Backpressure::Error, /Unknown provider/)
    end
  end

  describe ".register" do
    it "registers a custom provider" do
      custom = Class.new(described_class)
      described_class.register(:custom_test, custom)
      expect(described_class.for(:custom_test, config: {})).to be_a(custom)
    ensure
      described_class.providers.delete(:custom_test)
    end
  end
end

RSpec.describe Backpressure::AI::Providers::Test do
  subject(:provider) { described_class.new(config: {}) }

  it "returns canned responses" do
    result = provider.complete(
      prompt: "test prompt",
      model: "test-model",
      temperature: 0.0,
      max_tokens: 100,
      schema: nil
    )
    expect(result).to eq([])
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/ai/provider_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/ai/provider.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module AI
    class Provider
      attr_reader :config

      def initialize(config:)
        @config = config
      end

      def complete(prompt:, model:, temperature:, max_tokens:, schema:)
        raise NotImplementedError
      end

      class << self
        def providers
          @providers ||= {}
        end

        def register(name, klass)
          providers[name.to_sym] = klass
        end

        def for(name, config:)
          klass = providers[name.to_sym]
          raise Backpressure::Error, "Unknown provider: #{name}" unless klass
          klass.new(config: config)
        end
      end
    end
  end
end

module Backpressure
  module AI
    module Providers
      class Test < Provider
        def complete(prompt:, model:, temperature:, max_tokens:, schema:)
          []
        end
      end
    end
  end
end

Backpressure::AI::Provider.register(:test, Backpressure::AI::Providers::Test)
```

Add autoloads for `AI::Provider` to `lib/backpressure.rb`:

```ruby
module AI
  autoload :Provider, "backpressure/ai/provider"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/ai/provider_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/ai/ vendor/local_gems/backpressure/spec/backpressure/ai/ vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add AI Provider interface with test provider"
```

---

### Task 18: AI Strategies

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/ai/strategy.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/ai/strategies/pre_filter.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/ai/strategies/consensus.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/ai/strategies_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/ai/strategies_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::AI::Strategies::PreFilter do
  it "skips files that don't match the pattern" do
    strategy = described_class.new(pattern: /MUST|SHOULD/)
    expect(strategy.should_run?("class Foo; end")).to be false
  end

  it "runs on files that match" do
    strategy = described_class.new(pattern: /MUST|SHOULD/)
    expect(strategy.should_run?("# MUST return a hash")).to be true
  end
end

RSpec.describe Backpressure::AI::Strategies::Consensus do
  let(:provider) { Backpressure::AI::Providers::Test.new(config: {}) }

  it "runs the check N times and reports majority-agreed violations" do
    call_count = 0
    responses = [
      [{ "line" => 5, "message" => "unclear constraint" }],
      [{ "line" => 5, "message" => "unclear constraint" }, { "line" => 10, "message" => "ambiguous" }],
      [{ "line" => 5, "message" => "unclear constraint" }]
    ]

    strategy = described_class.new(count: 3)
    result = strategy.evaluate do |_attempt|
      r = responses[call_count]
      call_count += 1
      r
    end

    agreed = result.select { |v| v[:agreed] }
    expect(agreed.size).to eq(1)
    expect(agreed.first[:line]).to eq(5)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/ai/strategies_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/ai/strategy.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module AI
    module Strategies
    end
  end
end
```

Create `vendor/local_gems/backpressure/lib/backpressure/ai/strategies/pre_filter.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module AI
    module Strategies
      class PreFilter
        def initialize(pattern:)
          @pattern = pattern.is_a?(String) ? Regexp.new(pattern) : pattern
        end

        def should_run?(source)
          source.match?(@pattern)
        end
      end
    end
  end
end
```

Create `vendor/local_gems/backpressure/lib/backpressure/ai/strategies/consensus.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module AI
    module Strategies
      class Consensus
        def initialize(count:)
          @count = count
        end

        def evaluate(&block)
          all_results = @count.times.map { |i| block.call(i) }

          vote_counts = Hash.new(0)
          all_results.flatten.each do |violation|
            key = violation.values_at("line", "message").join(":")
            vote_counts[key] += 1
          end

          threshold = (@count / 2.0).ceil

          all_violations = all_results.flatten.uniq { |v| v.values_at("line", "message").join(":") }
          all_violations.map do |v|
            key = v.values_at("line", "message").join(":")
            v.merge(agreed: vote_counts[key] >= threshold, votes: vote_counts[key])
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/ai/strategies_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/ai/strategy.rb vendor/local_gems/backpressure/lib/backpressure/ai/strategies/ vendor/local_gems/backpressure/spec/backpressure/ai/strategies_spec.rb
git commit -m "feat(backpressure): add PreFilter and Consensus AI strategies"
```

---

### Task 19: AiCheck and YAML Loader

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/ai_check.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/yaml_loader.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/ai_check_spec.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/yaml_loader_spec.rb`

- [ ] **Step 1: Write the failing tests**

Create `vendor/local_gems/backpressure/spec/backpressure/ai_check_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Backpressure::AiCheck do
  let(:check_class) do
    Class.new(described_class) do
      category "AI/Test"
      files "**/*.rb"
      requires :source

      def self.name; "TestAiCheck"; end

      ai_config(
        provider: :test,
        model: "test-model",
        temperature: 0.1,
        max_tokens: 100
      )

      prompt_template "Analyze this code: {{source}}"
    end
  end

  it "has ai_settings" do
    expect(check_class.ai_settings[:provider]).to eq(:test)
    expect(check_class.ai_settings[:model]).to eq("test-model")
  end

  it "has a prompt template" do
    expect(check_class.prompt_text).to include("Analyze this code")
  end

  it "runs with the test provider and produces no violations" do
    context = Backpressure::Contexts::SourceContext.new(source: "class Foo; end", file_path: "foo.rb")
    instance = check_class.new
    instance.run(context)
    expect(instance.violations).to be_empty
  end
end
```

Create `vendor/local_gems/backpressure/spec/backpressure/yaml_loader_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::YamlLoader do
  let(:tmpdir) { Dir.mktmpdir("bp_yaml") }

  after { FileUtils.remove_entry(tmpdir) }

  it "loads a YAML check file and returns a check class" do
    yaml_path = File.join(tmpdir, "test_check.check.yml")
    File.write(yaml_path, <<~YAML)
      name: TestYamlCheck
      category: AI/Test
      files: "**/*.rb"
      requires: source
      severity: warning
      ai:
        provider: test
        model: test-model
        temperature: 0.1
        max_tokens: 100
      prompt: "Check this code for issues"
    YAML

    klass = described_class.load(yaml_path)

    expect(klass.check_name).to eq("TestYamlCheck")
    expect(klass.check_category).to eq("AI/Test")
    expect(klass.check_severity).to eq(:warning)
    expect(klass.file_glob).to eq("**/*.rb")
    expect(klass.ai_settings[:provider]).to eq(:test)
    expect(klass.prompt_text).to eq("Check this code for issues")
  end

  it "loads all YAML checks from a directory" do
    File.write(File.join(tmpdir, "a.check.yml"), <<~YAML)
      name: CheckA
      category: Test
      files: "**/*.rb"
      requires: source
      ai:
        provider: test
        model: m
      prompt: "test"
    YAML

    File.write(File.join(tmpdir, "b.check.yml"), <<~YAML)
      name: CheckB
      category: Test
      files: "**/*.rb"
      requires: source
      ai:
        provider: test
        model: m
      prompt: "test"
    YAML

    classes = described_class.load_all(tmpdir)
    expect(classes.map(&:check_name)).to contain_exactly("CheckA", "CheckB")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/ai_check_spec.rb spec/backpressure/yaml_loader_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/ai_check.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  class AiCheck < Check
    class << self
      def ai_config(settings = nil)
        if settings
          @ai_settings = settings
        else
          @ai_settings
        end
      end

      def ai_settings
        @ai_settings || (superclass.respond_to?(:ai_settings) ? superclass.ai_settings : {})
      end

      def prompt_template(text = nil)
        if text
          @prompt_text = text
        else
          @prompt_text
        end
      end

      def prompt_text
        @prompt_text || (superclass.respond_to?(:prompt_text) ? superclass.prompt_text : nil)
      end
    end

    def check(context)
      settings = self.class.ai_settings
      provider = AI::Provider.for(settings[:provider], config: Backpressure.configuration.ai_config)

      prompt = render_prompt(context)
      results = provider.complete(
        prompt: prompt,
        model: settings[:model],
        temperature: settings.fetch(:temperature, 0.1),
        max_tokens: settings.fetch(:max_tokens, 1024),
        schema: settings[:schema]
      )

      interpret(results, context)
    end

    def interpret(results, context)
      Array(results).each do |r|
        line = r["line"] || r[:line] || 0
        message = r["message"] || r[:message] || "AI violation"
        node = OpenStruct.new(loc: OpenStruct.new(line: line, column: 0))
        violation(node, message)
      end
    end

    private

    def render_prompt(context)
      template = self.class.prompt_text || ""
      template.gsub("{{source}}", context.source)
    end
  end
end
```

Create `vendor/local_gems/backpressure/lib/backpressure/yaml_loader.rb`:

```ruby
# frozen_string_literal: true

require "yaml"

module Backpressure
  class YamlLoader
    def self.load(path)
      data = YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
      build_check_class(data)
    end

    def self.load_all(directory)
      Dir.glob(File.join(directory, "**", "*.check.yml")).sort.map { |path| load(path) }
    end

    def self.build_check_class(data)
      klass = Class.new(AiCheck)

      klass_name = data["name"]
      klass.define_singleton_method(:name) { klass_name }
      klass.define_singleton_method(:check_name) { klass_name }

      klass.category(data["category"]) if data["category"]
      klass.severity(data["severity"]&.to_sym) if data["severity"]
      klass.files(data["files"]) if data["files"]
      klass.requires(*Array(data["requires"]).map(&:to_sym)) if data["requires"]

      ai_data = data["ai"] || {}
      klass.ai_config(
        provider: ai_data["provider"]&.to_sym,
        model: ai_data["model"],
        temperature: ai_data["temperature"],
        max_tokens: ai_data["max_tokens"],
        timeout: ai_data["timeout"],
        strategy: ai_data["strategy"],
        schema: ai_data["schema"]
      )

      klass.prompt_template(data["prompt"]) if data["prompt"]

      klass
    end
  end
end
```

Add autoloads to `lib/backpressure.rb`:

```ruby
autoload :AiCheck, "backpressure/ai_check"
autoload :YamlLoader, "backpressure/yaml_loader"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/ai_check_spec.rb spec/backpressure/yaml_loader_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/ai_check.rb vendor/local_gems/backpressure/lib/backpressure/yaml_loader.rb vendor/local_gems/backpressure/spec/backpressure/ai_check_spec.rb vendor/local_gems/backpressure/spec/backpressure/yaml_loader_spec.rb vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add AiCheck and YAML loader for AI check definitions"
```

---

## Phase 5: Group & Project Contexts

### Task 20: Group Context

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/contexts/group_context.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/contexts/group_context_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/contexts/group_context_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::Contexts::GroupContext do
  let(:tmpdir) { Dir.mktmpdir("bp_group") }

  after { FileUtils.remove_entry(tmpdir) }

  it "provides access to grouped files by role" do
    agent_path = File.join(tmpdir, "agent.rb")
    prompt_path = File.join(tmpdir, "prompt.rb")
    File.write(agent_path, "class Agent; end")
    File.write(prompt_path, "class Prompt; end")

    roles = { agent: agent_path, prompt: prompt_path }
    context = described_class.new(roles: roles, primary_role: :agent)

    expect(context.file_path).to eq(agent_path)
    expect(context.group[:agent]).to be_a(Backpressure::Contexts::SourceContext)
    expect(context.group[:prompt]).to be_a(Backpressure::Contexts::SourceContext)
    expect(context.group[:agent].source).to eq("class Agent; end")
  end

  it "handles missing companion files" do
    agent_path = File.join(tmpdir, "agent.rb")
    File.write(agent_path, "class Agent; end")

    roles = { agent: agent_path, prompt: File.join(tmpdir, "missing.rb") }
    context = described_class.new(roles: roles, primary_role: :agent)

    expect(context.group[:agent]).to be_a(Backpressure::Contexts::SourceContext)
    expect(context.group[:prompt]).to be_nil
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/contexts/group_context_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/contexts/group_context.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module Contexts
    class GroupContext
      attr_reader :file_path, :group

      def initialize(roles:, primary_role:)
        @file_path = roles[primary_role]
        @group = build_group(roles)
      end

      def source
        primary_context&.source
      end

      private

      def build_group(roles)
        roles.transform_values do |path|
          if File.exist?(path)
            SourceContext.from_file(path)
          end
        end
      end

      def primary_context
        @group.values.compact.first
      end
    end
  end
end
```

Add `autoload :GroupContext, "backpressure/contexts/group_context"` to the Contexts module in `lib/backpressure.rb`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/contexts/group_context_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/contexts/group_context.rb vendor/local_gems/backpressure/spec/backpressure/contexts/group_context_spec.rb vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add GroupContext for multi-file checks"
```

---

### Task 21: Project Index and Project Context

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/project_index.rb`
- Create: `vendor/local_gems/backpressure/lib/backpressure/contexts/project_context.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/project_index_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/project_index_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::ProjectIndex do
  let(:tmpdir) { Dir.mktmpdir("bp_index") }

  after { FileUtils.remove_entry(tmpdir) }

  before do
    File.write(File.join(tmpdir, "user.rb"), <<~RUBY)
      class User < ApplicationRecord
        has_many :posts
      end
    RUBY

    File.write(File.join(tmpdir, "post.rb"), <<~RUBY)
      class Post < ApplicationRecord
        belongs_to :user
        def publish!
          update!(published: true)
        end
      end
    RUBY

    File.write(File.join(tmpdir, "users_controller.rb"), <<~RUBY)
      class UsersController
        def index
          User.where(active: true)
        end
      end
    RUBY
  end

  subject(:index) { described_class.build(Dir.glob(File.join(tmpdir, "*.rb"))) }

  it "indexes class definitions" do
    classes = index.classes
    expect(classes.map(&:name)).to contain_exactly("User", "Post", "UsersController")
  end

  it "finds classes in a glob pattern" do
    pattern = File.join(tmpdir, "user*.rb")
    matches = index.classes_in(pattern)
    expect(matches.map(&:name)).to contain_exactly("User", "UsersController")
  end

  it "finds classes by name pattern" do
    matches = index.classes_matching(/Controller$/)
    expect(matches.map(&:name)).to eq(["UsersController"])
  end
end

RSpec.describe Backpressure::Contexts::ProjectContext do
  let(:tmpdir) { Dir.mktmpdir("bp_proj") }

  after { FileUtils.remove_entry(tmpdir) }

  it "wraps ProjectIndex and provides file_path" do
    File.write(File.join(tmpdir, "a.rb"), "class A; end")
    files = Dir.glob(File.join(tmpdir, "*.rb"))
    index = Backpressure::ProjectIndex.build(files)
    context = described_class.new(project: index, file_path: files.first)

    expect(context.project).to eq(index)
    expect(context.file_path).to eq(files.first)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/project_index_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/project_index.rb`:

```ruby
# frozen_string_literal: true

require "rubocop-ast"

module Backpressure
  class ProjectIndex
    ClassEntry = Struct.new(:name, :file, :node, :superclass_name, keyword_init: true)

    attr_reader :classes, :files

    def initialize(classes:, files:)
      @classes = classes
      @files = files
    end

    def self.build(file_paths)
      all_classes = []
      file_paths.each do |path|
        source = File.read(path)
        processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
        next unless processed.ast

        processed.ast.each_node(:class) do |node|
          name = node.children[0]&.source
          superclass = node.children[1]&.source
          all_classes << ClassEntry.new(
            name: name,
            file: path,
            node: node,
            superclass_name: superclass
          )
        end
      end

      new(classes: all_classes, files: file_paths)
    end

    def classes_in(glob)
      classes.select { |c| File.fnmatch(glob, c.file, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
    end

    def classes_matching(pattern)
      classes.select { |c| c.name.match?(pattern) }
    end

    def references_to(target_classes)
      target_names = target_classes.map(&:name)
      refs = []

      files.each do |path|
        source = File.read(path)
        processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
        next unless processed.ast

        processed.ast.each_node(:const) do |node|
          const_name = node.source
          if target_names.include?(const_name)
            target = target_classes.find { |c| c.name == const_name }
            refs << OpenStruct.new(file: path, node: node, target: target)
          end
        end
      end

      refs
    end
  end
end
```

Create `vendor/local_gems/backpressure/lib/backpressure/contexts/project_context.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  module Contexts
    class ProjectContext
      attr_reader :project, :file_path

      def initialize(project:, file_path:)
        @project = project
        @file_path = file_path
      end

      def source
        File.read(file_path)
      end
    end
  end
end
```

Add autoloads to `lib/backpressure.rb`:

```ruby
autoload :ProjectIndex, "backpressure/project_index"
```

And in the Contexts module:

```ruby
autoload :ProjectContext, "backpressure/contexts/project_context"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/project_index_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/project_index.rb vendor/local_gems/backpressure/lib/backpressure/contexts/project_context.rb vendor/local_gems/backpressure/spec/backpressure/project_index_spec.rb vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add ProjectIndex and ProjectContext for cross-file checks"
```

---

## Phase 6: Plugin System

### Task 22: Plugin Registration

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/plugin.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/plugin_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/plugin_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Plugin system" do
  let(:tmpdir) { Dir.mktmpdir("bp_plugin") }

  after do
    FileUtils.remove_entry(tmpdir)
    Backpressure.reset!
  end

  it "registers a plugin with checks" do
    checks_dir = File.join(tmpdir, "checks")
    FileUtils.mkdir_p(checks_dir)
    File.write(File.join(checks_dir, "plugin_check.rb"), <<~RUBY)
      class PluginCheck < Backpressure::Check
        category "Plugin"
        def check(context); end
      end
    RUBY

    Backpressure.register_plugin "test_plugin" do
      checks_from checks_dir
    end

    expect(Backpressure.registry.by_name("PluginCheck")).not_to be_nil
  end

  it "registers a custom formatter" do
    custom_formatter = Class.new(Backpressure::Formatters::Base) do
      def format(violations)
        "custom: #{violations.size}"
      end
    end

    Backpressure.register_plugin "fmt_plugin" do
      formatter :custom, custom_formatter
    end

    expect(Backpressure.formatter_registry[:custom]).to eq(custom_formatter)
  end

  it "registers a custom context type" do
    Backpressure.register_plugin "ctx_plugin" do
      context :custom_ctx do |source, file_path|
        OpenStruct.new(data: source.upcase, file_path: file_path)
      end
    end

    expect(Backpressure.context_registry[:custom_ctx]).to be_a(Proc)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/plugin_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/plugin.rb`:

```ruby
# frozen_string_literal: true

module Backpressure
  class PluginDSL
    def initialize(name, &block)
      @name = name
      instance_eval(&block)
    end

    def checks_from(directory)
      Backpressure.registry.load_from(directory)
    end

    def formatter(name, klass)
      Backpressure.formatter_registry[name.to_sym] = klass
    end

    def context(name, &block)
      Backpressure.context_registry[name.to_sym] = block
    end
  end

  class << self
    def register_plugin(name, &block)
      PluginDSL.new(name, &block)
    end

    def formatter_registry
      @formatter_registry ||= {}
    end

    def context_registry
      @context_registry ||= {}
    end

    def reset!
      @configuration = nil
      @registry = nil
      @formatter_registry = nil
      @context_registry = nil
    end
  end
end
```

Update `lib/backpressure.rb` to require plugin:

```ruby
autoload :PluginDSL, "backpressure/plugin"
```

And update the `reset!` method in the main module to delegate to the plugin reset.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/plugin_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/plugin.rb vendor/local_gems/backpressure/spec/backpressure/plugin_spec.rb vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add Plugin system with context, formatter, and check registration"
```

---

## Phase 7: RuboCop Compilation

### Task 23: RuboCop Compiler

**Files:**
- Create: `vendor/local_gems/backpressure/lib/backpressure/compiler/rubocop_compiler.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/compiler/rubocop_compiler_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/compiler/rubocop_compiler_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::Compiler::RubocopCompiler do
  let(:tmpdir) { Dir.mktmpdir("bp_compile") }

  after { FileUtils.remove_entry(tmpdir) }

  let(:compilable_check) do
    Class.new(Backpressure::Check) do
      requires :ast
      compilable
      category "Architecture"

      def self.name; "NoDirectAR"; end

      def check(context)
        context.ast.each_node(:send) do |node|
          if node.method_name == :where
            violation(node, "Use a service object")
          end
        end
      end
    end
  end

  let(:non_compilable_check) do
    Class.new(Backpressure::Check) do
      requires :ast, :project
      category "Architecture"
      def self.name; "CrossFileCheck"; end
      def check(context); end
    end
  end

  describe "#compilable?" do
    it "returns true for ast-only compilable checks" do
      expect(described_class.compilable?(compilable_check)).to be true
    end

    it "returns false for checks with project dependency" do
      expect(described_class.compilable?(non_compilable_check)).to be false
    end
  end

  describe "#compile" do
    it "generates a RuboCop cop file" do
      output_dir = File.join(tmpdir, "lib/rubocop/cop/backpressure")
      described_class.new(output_dir: output_dir).compile(compilable_check)

      cop_path = File.join(output_dir, "no_direct_ar.rb")
      expect(File.exist?(cop_path)).to be true

      content = File.read(cop_path)
      expect(content).to include("module RuboCop")
      expect(content).to include("class NoDirectAR")
      expect(content).to include("Backpressure/NoDirectAR")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/compiler/rubocop_compiler_spec.rb`

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `vendor/local_gems/backpressure/lib/backpressure/compiler/rubocop_compiler.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"

module Backpressure
  module Compiler
    class RubocopCompiler
      def initialize(output_dir:)
        @output_dir = output_dir
      end

      def self.compilable?(check_class)
        return false unless check_class.respond_to?(:compilable?) && check_class.compilable?
        contexts = check_class.required_contexts || []
        contexts == [:ast]
      end

      def compile(check_class)
        FileUtils.mkdir_p(@output_dir)

        cop_name = check_class.check_name
        file_name = cop_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
        output_path = File.join(@output_dir, "#{file_name}.rb")

        content = generate_cop(cop_name, check_class)
        File.write(output_path, content)
        output_path
      end

      private

      def generate_cop(cop_name, check_class)
        <<~RUBY
          # frozen_string_literal: true

          # Auto-generated by backpressure compile --rubocop
          # Source: #{check_class.name || cop_name}

          module RuboCop
            module Cop
              module Backpressure
                class #{cop_name} < Base
                  MSG = "Backpressure/#{cop_name}: violation detected"

                  def on_new_investigation
                    @check = create_backpressure_check
                    context = ::Backpressure::Contexts::AstContext.new(
                      source: processed_source.buffer.source,
                      file_path: processed_source.file_path
                    )
                    @check.run(context)
                    @check.violations.each do |v|
                      node = find_node_at(v.line, v.column)
                      add_offense(node || processed_source.ast, message: v.message) if node || processed_source.ast
                    end
                  end

                  private

                  def create_backpressure_check
                    ::#{check_class.name || cop_name}.new
                  end

                  def find_node_at(line, column)
                    processed_source.ast.each_node do |node|
                      return node if node.loc&.line == line
                    end
                    nil
                  end
                end
              end
            end
          end
        RUBY
      end
    end
  end
end
```

Add autoload:

```ruby
module Compiler
  autoload :RubocopCompiler, "backpressure/compiler/rubocop_compiler"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/compiler/rubocop_compiler_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/compiler/ vendor/local_gems/backpressure/spec/backpressure/compiler/ vendor/local_gems/backpressure/lib/backpressure.rb
git commit -m "feat(backpressure): add RuboCop compiler for compilable AST checks"
```

---

## Phase 8: Final Integration

### Task 24: Skip Annotations

**Files:**
- Modify: `vendor/local_gems/backpressure/lib/backpressure/runner.rb`
- Create: `vendor/local_gems/backpressure/spec/backpressure/skip_annotations_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `vendor/local_gems/backpressure/spec/backpressure/skip_annotations_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Skip annotations" do
  let(:tmpdir) { Dir.mktmpdir("bp_skip") }

  after { FileUtils.remove_entry(tmpdir) }

  let(:check_class) do
    Class.new(Backpressure::Check) do
      files "**/*.rb"
      requires :source
      def self.name; "NoPuts"; end
      def check(context)
        context.lines.each_with_index do |line, idx|
          if line.match?(/\bputs\b/) && !line.match?(/backpressure:disable/)
            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            violation(node, "No puts")
          end
        end
      end
    end
  end

  it "filters violations on lines with backpressure:disable" do
    target = File.join(tmpdir, "test.rb")
    File.write(target, <<~RUBY)
      puts "this should fail"
      puts "this is ok" # backpressure:disable NoPuts
      puts "also fails"
    RUBY

    registry = Backpressure::CheckRegistry.new
    registry.register(check_class)
    config = Backpressure::Configuration.new
    runner = Backpressure::Runner.new(config: config, registry: registry)
    result = runner.run(files: [target])

    expect(result.violations.size).to eq(2)
    expect(result.violations.map(&:line)).to contain_exactly(1, 3)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/skip_annotations_spec.rb`

Expected: FAIL (currently all 3 lines produce violations)

- [ ] **Step 3: Modify Runner to filter skip annotations**

Add a post-processing step to `Runner#run` that filters violations on lines with `# backpressure:disable`:

In `vendor/local_gems/backpressure/lib/backpressure/runner.rb`, after collecting violations from a check, filter by skip annotations:

```ruby
def filter_skip_annotations(violations, source)
  lines = source.lines
  violations.reject do |v|
    line = lines[v.line - 1]
    next false unless line
    if line.match?(/backpressure:disable\s+(\S+)/)
      disabled = line.match(/backpressure:disable\s+(.+)/)[1].split(",").map(&:strip)
      disabled.include?(v.check_name) || disabled.include?("all")
    else
      false
    end
  end
end
```

Call this method in `run` after each check produces violations, before adding to `all_violations`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/backpressure/skip_annotations_spec.rb`

Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add vendor/local_gems/backpressure/lib/backpressure/runner.rb vendor/local_gems/backpressure/spec/backpressure/skip_annotations_spec.rb
git commit -m "feat(backpressure): add skip annotation support (# backpressure:disable)"
```

---

### Task 25: Full Integration Test

**Files:**
- Create: `vendor/local_gems/backpressure/spec/integration/full_flow_spec.rb`

- [ ] **Step 1: Write the integration test**

Create `vendor/local_gems/backpressure/spec/integration/full_flow_spec.rb`:

```ruby
# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Full backpressure flow" do
  let(:project) { Dir.mktmpdir("bp_full") }

  after { FileUtils.remove_entry(project) }

  it "runs checks, ratchets, caches, and reports violations end-to-end" do
    checks_dir = File.join(project, "checks")
    FileUtils.mkdir_p(checks_dir)

    File.write(File.join(checks_dir, "no_puts.rb"), <<~RUBY)
      class NoPuts < Backpressure::Check
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

    # First run: get violations
    result = runner.run(files: [target])
    expect(result.violations.size).to eq(1)

    # Create baseline
    baseline_path = File.join(project, "baseline.yml")
    ratchet = Backpressure::Ratchet.new(baseline_path: baseline_path, anti_tamper: true)
    ratchet.update_baseline(result.violations)

    # Same violations: ratchet passes
    ratchet_result = ratchet.evaluate(result.violations)
    expect(ratchet_result.pass?).to be true

    # Add a new puts: ratchet fails
    File.write(target, "class App\n  def run\n    puts 'hello'\n    puts 'world'\n  end\nend\n")
    result2 = runner.run(files: [target])
    expect(result2.violations.size).to eq(2)

    ratchet_result2 = ratchet.evaluate(result2.violations)
    expect(ratchet_result2.pass?).to be false
    expect(ratchet_result2.new_violations.size).to eq(1)

    # Cache: second run is cached
    cache = Backpressure::Cache.new(dir: File.join(project, ".cache"))
    cache.store(
      check_name: "NoPuts", file_path: target,
      file_content: File.read(target), check_version: "v1",
      result: [{ line: 3, message: "Avoid puts" }]
    )
    cached = cache.fetch(
      check_name: "NoPuts", file_path: target,
      file_content: File.read(target), check_version: "v1"
    )
    expect(cached).not_to be_nil

    # JSON output
    json = Backpressure::Formatters::Json.new.format(result2.violations)
    parsed = JSON.parse(json)
    expect(parsed.size).to eq(2)
  end
end
```

- [ ] **Step 2: Run integration test**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec spec/integration/full_flow_spec.rb`

Expected: All pass

- [ ] **Step 3: Run full test suite**

Run: `cd vendor/local_gems/backpressure && bundle exec rspec`

Expected: All specs pass

- [ ] **Step 4: Commit**

```bash
git add vendor/local_gems/backpressure/spec/integration/full_flow_spec.rb
git commit -m "test(backpressure): add full end-to-end integration test"
```

---

### Task 26: Wire into ProspectsRadar Gemfile

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add backpressure to Gemfile**

Add to the Gemfile in the appropriate section (near other local gems):

```ruby
gem "backpressure", path: "vendor/local_gems/backpressure"
```

- [ ] **Step 2: Bundle install**

Run: `bundle install`

Expected: Successfully installs backpressure gem

- [ ] **Step 3: Verify it loads**

Run: `bundle exec ruby -e "require 'backpressure'; puts Backpressure::VERSION"`

Expected: `0.1.0`

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "feat: wire backpressure gem into ProspectsRadar"
```

---

## Summary

| Phase | Tasks | What's Working After |
|-------|-------|---------------------|
| 1: Foundation | 1-12 | Gem scaffold, Check DSL, AST/Source contexts, Registry, Config, Runner, CLI, Formatters, integration test |
| 2: Ratcheting & Caching | 13-15 | Baseline snapshots, anti-tamper, content-hash cache |
| 3: Auto-Fix | 16 | Replace/Insert/Remove corrections |
| 4: AI Layer | 17-19 | Provider interface, PreFilter/Consensus strategies, AiCheck, YAML loader |
| 5: Group & Project | 20-21 | GroupContext for file pairs, ProjectIndex for cross-file checks |
| 6: Plugin System | 22 | Plugin registration for contexts, formatters, checks |
| 7: RuboCop Compilation | 23 | Compile AST checks to RuboCop cops |
| 8: Final Integration | 24-26 | Skip annotations, full integration test, wired into ProspectsRadar |
