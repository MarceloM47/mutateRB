# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe MutateRB::ProgressReporter do
  let(:io) { StringIO.new }
  let(:reporter) { described_class.new(io: io, tick_interval: 0.01) }

  let(:mutant) do
    MutateRB::Mutant.new(id: "m1", operator_type: :boolean_literal, file_path: "lib/foo.rb",
                         line: 3, column_range: 0..3, original_fragment: "true",
                         mutated_fragment: "false")
  end

  it "announces the baseline phase immediately" do
    reporter.start_baseline
    reporter.finish_baseline

    expect(io.string).to include("Running baseline tests...")
  end

  it "increments processed count as mutants finish, without raising" do
    reporter.start_mutants(2)
    expect { reporter.mutant_finished(mutant) }.not_to raise_error
    expect { reporter.mutant_finished(mutant) }.not_to raise_error
    reporter.finish_mutants
  end

  it "does not print a per-mutant line when verbose is false" do
    non_verbose = described_class.new(io: io, tick_interval: 0.01, verbose: false)
    non_verbose.start_mutants(1)
    non_verbose.mutant_finished(mutant)
    non_verbose.finish_mutants

    expect(io.string).not_to include(mutant.file_path)
  end

  it "the ticker thread never propagates an exception into the caller" do
    reporter.start_baseline
    sleep 0.05 # let a few ticks happen
    expect { reporter.finish_baseline }.not_to raise_error
  end

  it "keeps ticking (drawing new output) while a phase is in progress" do
    reporter.start_baseline
    sleep 0.05
    first_snapshot = io.string.dup
    sleep 0.05
    second_snapshot = io.string
    reporter.finish_baseline

    expect(second_snapshot.length).to be > first_snapshot.length
  end

  context "with verbose: true" do
    let(:verbose_reporter) { described_class.new(io: io, tick_interval: 0.01, verbose: true) }

    it "prints one line per mutant with file, line, operator type, and result" do
      killed = mutant
      killed.finish!(status: :killed, kill_reason: :assertion_failure)

      verbose_reporter.start_mutants(1)
      verbose_reporter.mutant_finished(killed)
      verbose_reporter.finish_mutants

      expect(io.string).to include("lib/foo.rb:3 [boolean_literal] 'true' -> 'false' => killed")
    end

    it "does not print the bare counter/ticker for the mutant loop" do
      verbose_reporter.start_mutants(1)
      sleep 0.05
      verbose_reporter.mutant_finished(mutant)
      verbose_reporter.finish_mutants

      expect(io.string).not_to include("Mutating...")
    end

    it "still announces and ticks the baseline phase (FR-005 only affects the mutant loop)" do
      verbose_reporter.start_baseline
      verbose_reporter.finish_baseline

      expect(io.string).to include("Running baseline tests...")
    end
  end

  context "when io is not a TTY (redirected output, CI)" do
    it "never writes a carriage return, only complete lines" do
      reporter.start_baseline
      sleep 0.05
      reporter.finish_baseline

      expect(io.string).not_to include("\r")
      expect(io.string.lines).to all(end_with("\n"))
    end

    it "uses a longer default tick interval than an interactive terminal" do
      tty_io = instance_double(IO, tty?: true)
      non_tty_reporter = described_class.new(io: io)
      tty_reporter = described_class.new(io: tty_io)

      expect(non_tty_reporter.send(:instance_variable_get, :@tick_interval))
        .to be > tty_reporter.send(:instance_variable_get, :@tick_interval)
    end
  end
end
