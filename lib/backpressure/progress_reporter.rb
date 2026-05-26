# frozen_string_literal: true

module Backpressure
  class ProgressReporter
    SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
    BAR_FILLED = "━"
    BAR_EMPTY  = "░"

    def initialize(io: $stderr)
      @io = io
      @tty = io.respond_to?(:tty?) && io.tty?
      @total_files = 0
      @current_file_index = 0
      @current_file = nil
      @current_check = nil
      @violation_count = 0
      @spinner_index = 0
      @start_time = nil
      @lines_written = 0
    end

    def start(total_files:)
      @total_files = total_files
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @violation_count = 0
      @current_file_index = 0
      render if @tty
    end

    def file_start(file_path, check_count)
      @current_file_index += 1
      @current_file = file_path
      @current_check = nil
      @current_check_count = check_count
      render if @tty
    end

    def check_start(check_name)
      @current_check = check_name
      @spinner_index = (@spinner_index + 1) % SPINNER.size
      render if @tty
    end

    def check_done(violation_count)
      @violation_count += violation_count
      @spinner_index = (@spinner_index + 1) % SPINNER.size
      render if @tty
    end

    def finish
      clear_lines if @tty
      elapsed = elapsed_time
      summary = "Scanned #{@total_files} file#{@total_files == 1 ? '' : 's'} " \
                "in #{format_duration(elapsed)} — " \
                "#{@violation_count} violation#{@violation_count == 1 ? '' : 's'} found"

      if @tty
        @io.puts "\e[32m✓\e[0m #{summary}"
      else
        @io.puts summary
      end
    end

    private

    def render
      clear_lines

      pct = @total_files > 0 ? (@current_file_index.to_f / @total_files * 100).round : 0
      bar = build_bar(pct)
      elapsed = elapsed_time

      spinner = SPINNER[@spinner_index]
      status_line = "#{spinner} #{bar} #{pct.to_s.rjust(3)}% " \
                    "\e[2m│\e[0m #{@current_file_index}/#{@total_files} files " \
                    "\e[2m│\e[0m #{@violation_count} violation#{@violation_count == 1 ? '' : 's'} " \
                    "\e[2m│\e[0m #{format_duration(elapsed)}"

      detail = if @current_file
                 short_file = shorten_path(@current_file)
                 if @current_check
                   "  \e[2m→ #{short_file} → \e[0;36m#{@current_check}\e[0m"
                 else
                   "  \e[2m→ #{short_file}\e[0m"
                 end
               end

      @io.write(status_line)
      if detail
        @io.write("\n#{detail}")
        @lines_written = 2
      else
        @lines_written = 1
      end
    end

    def clear_lines
      return unless @lines_written > 0

      @io.write("\r\e[K")
      (@lines_written - 1).times { @io.write("\e[A\r\e[K") }
      @lines_written = 0
    end

    def build_bar(pct)
      width = terminal_width
      bar_width = [width - 60, 10].max
      bar_width = [bar_width, 40].min

      filled = (bar_width * pct / 100.0).round
      empty = bar_width - filled

      "\e[32m#{BAR_FILLED * filled}\e[0m#{BAR_EMPTY * empty}"
    end

    def terminal_width
      if @io.respond_to?(:winsize)
        @io.winsize[1]
      else
        80
      end
    rescue StandardError
      80
    end

    def shorten_path(path)
      path.sub(Dir.pwd + "/", "")
    end

    def elapsed_time
      return 0 unless @start_time

      Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
    end

    def format_duration(seconds)
      if seconds < 60
        "#{seconds.round(1)}s"
      else
        mins = (seconds / 60).floor
        secs = (seconds % 60).round
        "#{mins}m#{secs}s"
      end
    end
  end
end
