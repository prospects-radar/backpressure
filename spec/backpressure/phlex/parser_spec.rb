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
