# frozen_string_literal: true

module MutateRB
  # Aggregates a complete run: the config used, the detected test suite, and
  # every mutant generated with its outcome (data-model.md).
  class MutationRun
    attr_reader :config, :test_suite, :mutants, :started_at
    attr_accessor :finished_at, :interrupted

    def initialize(config:, test_suite:)
      @config = config
      @test_suite = test_suite
      @mutants = []
      @started_at = Time.now
      @finished_at = nil
      @interrupted = false
    end

    def add_mutant(mutant)
      raise ArgumentError, "expected a Mutant" unless mutant.is_a?(Mutant)

      @mutants << mutant
      mutant
    end

    def baseline_broken_tests
      test_suite.baseline_broken_tests
    end

    def survived?
      mutants.any?(&:survived?)
    end

    def survived_mutants
      mutants.select(&:survived?)
    end

    def summary
      {
        total_mutants: mutants.size,
        killed: mutants.count(&:killed?),
        survived: mutants.count(&:survived?),
        errors: mutants.count(&:error?),
        baseline_broken_tests: baseline_broken_tests.size
      }
    end

    # Exit code for a normal (non-interrupted) completion. SIGINT is handled
    # separately by the CLI's signal trap (contracts/cli.md: exit 130).
    def exit_code
      return 0 unless survived?
      return 0 unless config.exit_on_survivors

      1
    end
  end
end
