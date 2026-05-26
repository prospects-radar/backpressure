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
