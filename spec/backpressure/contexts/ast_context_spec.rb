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
