# frozen_string_literal: true

RSpec.describe Backpressure::ProgressReporter do
  let(:io) { StringIO.new }
  subject(:reporter) { described_class.new(io: io) }

  describe "#start" do
    it "records the total file count" do
      reporter.start(total_files: 10)
      reporter.finish
      expect(io.string).to include("10 files")
    end
  end

  describe "#file_start / #check_start / #check_done" do
    it "tracks violation counts across checks" do
      reporter.start(total_files: 2)
      reporter.file_start("app/models/user.rb", 2)
      reporter.check_start("TodoTracker")
      reporter.check_done(3)
      reporter.check_start("DeadRequire")
      reporter.check_done(1)
      reporter.file_start("app/models/account.rb", 1)
      reporter.check_start("TodoTracker")
      reporter.check_done(0)
      reporter.finish

      expect(io.string).to include("4 violations")
    end
  end

  describe "#finish" do
    it "prints a summary line" do
      reporter.start(total_files: 5)
      reporter.finish

      expect(io.string).to include("Scanned 5 files")
    end

    it "handles singular file" do
      reporter.start(total_files: 1)
      reporter.finish

      expect(io.string).to include("1 file ")
    end

    it "handles singular violation" do
      reporter.start(total_files: 1)
      reporter.file_start("f.rb", 1)
      reporter.check_start("X")
      reporter.check_done(1)
      reporter.finish

      expect(io.string).to include("1 violation ")
    end
  end

  describe "TTY rendering" do
    it "does not render progress lines to non-TTY, only the summary" do
      reporter.start(total_files: 3)
      reporter.file_start("a.rb", 1)
      reporter.check_start("X")
      reporter.check_done(0)

      output_before_finish = io.string.dup
      expect(output_before_finish).to eq("")

      reporter.finish
      expect(io.string).to include("Scanned 3 files")
    end
  end

  describe "with runner integration" do
    it "receives callbacks during a runner execution" do
      events = []
      reporter = described_class.new(io: io)
      allow(reporter).to receive(:start).and_wrap_original { |m, **kw| events << [:start, kw]; m.call(**kw) }
      allow(reporter).to receive(:file_start).and_wrap_original { |m, *a| events << [:file_start, a.first]; m.call(*a) }
      allow(reporter).to receive(:check_start).and_wrap_original { |m, n| events << [:check_start, n]; m.call(n) }
      allow(reporter).to receive(:check_done).and_wrap_original { |m, c| events << [:check_done, c]; m.call(c) }
      allow(reporter).to receive(:finish).and_wrap_original { |m| events << [:finish]; m.call }

      config = Backpressure::Configuration.new
      registry = Backpressure::CheckRegistry.new

      check_class = Class.new(Backpressure::Check) do
        define_singleton_method(:name) { "TestCheck" }
        define_singleton_method(:check_name) { "TestCheck" }
        files "**/*.rb"
        requires :source

        def check(context)
          violation(OpenStruct.new(loc: OpenStruct.new(line: 1, column: 0)), "test")
        end
      end
      registry.register(check_class)

      Dir.mktmpdir do |dir|
        file = File.join(dir, "test.rb")
        File.write(file, "x = 1\n")

        runner = Backpressure::Runner.new(config: config, registry: registry, reporter: reporter)
        runner.run(files: [file])
      end

      expect(events.map(&:first)).to eq(%i[start file_start check_start check_done finish])
      expect(events.find { |e| e.first == :check_done }.last).to eq(1)
    end
  end
end
