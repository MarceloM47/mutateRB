# frozen_string_literal: true

module MutateRB
  # Live feedback for a run in progress (FR-001 to FR-005, FR-007): mutaterb used to print
  # nothing between start and the final summary, so a long run was indistinguishable from a
  # hang. A background thread ticks a status line on a timer, independent of whether the
  # baseline suite or a single mutant's tests have actually finished (FR-003a) — the real work
  # happens inside an opaque, blocking subprocess call, so this is the only way to keep the
  # terminal changing during a slow phase.
  class ProgressReporter
    SPINNER_FRAMES = %w[| / - \\].freeze
    TTY_TICK_INTERVAL = 0.3
    NON_TTY_TICK_INTERVAL = 5

    def initialize(io: $stdout, verbose: false, tick_interval: nil)
      @io = io
      @verbose = verbose
      @tick_interval = tick_interval || (io.tty? ? TTY_TICK_INTERVAL : NON_TTY_TICK_INTERVAL)
      @mutex = Mutex.new
      @phase = :idle
      @processed = 0
      @total = 0
      @phase_started_at = nil
      @ticker_thread = nil
    end

    def start_baseline
      @mutex.synchronize do
        @phase = :baseline
        @phase_started_at = Time.now
      end
      @io.puts "Running baseline tests..."
      start_ticker
    end

    def finish_baseline
      stop_ticker
    end

    def start_mutants(total)
      @mutex.synchronize do
        @phase = :mutating
        @processed = 0
        @total = total
        @phase_started_at = Time.now
      end
      start_ticker unless @verbose
    end

    # In verbose mode, this line IS the progress indicator for the mutant loop (FR-005):
    # the bare counter/ticker never runs, so there is nothing to interleave with it.
    def mutant_finished(mutant)
      if @verbose
        print_mutant_line(mutant)
      else
        @mutex.synchronize { @processed += 1 }
      end
    end

    def finish_mutants
      stop_ticker
      @mutex.synchronize { @phase = :done }
    end

    private

    def print_mutant_line(mutant)
      @io.puts "#{mutant.file_path}:#{mutant.line} [#{mutant.operator_type}] " \
               "'#{mutant.original_fragment}' -> '#{mutant.mutated_fragment}' => #{mutant.status}"
    end

    def start_ticker
      @ticker_thread = Thread.new { tick_loop }
    end

    def stop_ticker
      return unless @ticker_thread

      @ticker_thread.kill
      @ticker_thread.join
      @ticker_thread = nil
      @io.puts if @io.tty?
    end

    # Never lets a rendering bug abort the real mutation run (Principio V): worst case, the
    # ticker just stops drawing and the run continues silently, exactly like before this
    # feature existed.
    def tick_loop
      loop do
        sleep @tick_interval
        draw
      end
    rescue StandardError
      nil
    end

    def draw
      line = current_line
      return unless line

      if @io.tty?
        @io.print "\r#{line}"
        @io.flush
      else
        @io.puts line
      end
    end

    def current_line
      @mutex.synchronize do
        next nil unless @phase_started_at

        elapsed = Time.now - @phase_started_at
        spinner = SPINNER_FRAMES[(elapsed / @tick_interval).to_i % SPINNER_FRAMES.size]
        case @phase
        when :baseline
          "Running baseline tests... (#{spinner} #{elapsed.round}s)"
        when :mutating
          "Mutating... #{@processed}/#{@total} (#{spinner} #{elapsed.round}s)"
        end
      end
    end
  end
end
