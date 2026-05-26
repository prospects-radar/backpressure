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
