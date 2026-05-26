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
