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
  spec.add_dependency "parser", "~> 3.3"
  spec.add_dependency "ostruct"

  spec.metadata["rubygems_mfa_required"] = "true"
end
