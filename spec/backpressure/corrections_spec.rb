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
