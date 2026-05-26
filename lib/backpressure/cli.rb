# frozen_string_literal: true

require "optparse"

module Backpressure
  class CLI
    COMMANDS = %w[check fix list init cache compile].freeze

    def self.parse(argv)
      options = {
        command: nil, only: nil, format: nil, paths: [],
        update_baseline: false, cache: true, ai_fix: false,
        interactive: false, dry_run: false, verbose: false
      }

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

        opts.on("--verbose", "Show files and checks as they run") do
          options[:verbose] = true
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

      load_checks(config, registry)

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

    def gem_root
      File.expand_path("../..", __dir__)
    end

    def load_checks(config, registry)
      bundled_checks = File.join(gem_root, "lib", "backpressure", "checks")
      registry.load_from(bundled_checks) if Dir.exist?(bundled_checks)

      bundled_yaml = File.join(gem_root, "checks", "yaml")
      if Dir.exist?(bundled_yaml)
        YamlLoader.load_all(bundled_yaml).each { |c| registry.register(c) }
      end

      bundled_checks_real = File.realpath(bundled_checks) rescue nil
      bundled_yaml_real = File.realpath(bundled_yaml) rescue nil

      config.check_paths.each do |path|
        next unless Dir.exist?(path)
        path_real = File.realpath(path) rescue path
        next if path_real == bundled_checks_real || path_real == bundled_yaml_real

        registry.load_from(path)
        YamlLoader.load_all(path).each { |c| registry.register(c) } if Dir.glob(File.join(path, "**/*.check.yml")).any?
      end
    end

    def load_config
      config_path = "backpressure.yml"
      if File.exist?(config_path)
        Configuration.from_file(config_path)
      else
        Configuration.new
      end
    end

    def build_reporter
      return nil if @options[:verbose]
      return nil if @options[:format] == :json
      return nil unless $stderr.respond_to?(:tty?) && $stderr.tty?

      ProgressReporter.new
    end

    def run_check(config, registry)
      files = resolve_files(config)
      reporter = build_reporter
      runner = Runner.new(config: config, registry: registry, verbose: @options[:verbose], reporter: reporter)
      result = runner.run(files: files, only: @options[:only])

      formatter = resolve_formatter(config)
      puts formatter.format(result.violations)

      exit(result.success? ? 0 : 1)
    end

    def run_list(registry)
      registry.all.sort_by { |c| [c.check_category || "", c.check_name] }.each do |check|
        line = "#{check.check_name.ljust(40)} #{(check.check_category || '-').ljust(20)}"
        line += " #{check.check_description}" if check.check_description
        puts line
      end
    end

    def run_fix(_config, _registry)
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

    def run_cache(_config)
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
