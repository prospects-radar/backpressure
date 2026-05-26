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
