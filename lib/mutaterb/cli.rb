# frozen_string_literal: true

module MutateRB
  # Entry point: parses flags, resolves Config, runs the mutation analysis
  # and returns the process exit code (contracts/cli.md).
  class CLI
    EXIT_OPERATIONAL_ERROR = 2
    EXIT_INTERRUPTED = 130

    def self.run(argv)
      new.run(argv)
    end

    def run(argv)
      config = resolve_config(argv)
      execute(config)
    rescue ConfigError => e
      warn "mutaterb: #{e.message}"
      EXIT_OPERATIONAL_ERROR
    rescue StandardError => e
      # Constitution Principle V: no error may go uncaught.
      # Any unforeseen failure (project detection, baseline run, etc.) is
      # reported in a controlled manner instead of propagating a raw backtrace
      # (contracts/cli.md: exit 2 = operational error, SC-005).
      warn "mutaterb: unexpected error: #{e.message}"
      EXIT_OPERATIONAL_ERROR
    end

    private

    def resolve_config(argv)
      flags = FlagParser.parse(argv)
      base = Config.load_file(flags.fetch(:config_path, Config::DEFAULT_FILE_NAME))
      base.merge_flags(flags.except(:config_path))
    end

    def execute(config)
      interrupted = false
      Signal.trap("INT") { interrupted = true }

      detection = ProjectDetector.new(config).detect
      if detection.test_files.empty?
        warn "mutaterb: no tests found in #{config.target_dir}"
        return EXIT_OPERATIONAL_ERROR
      end
      warn_ambiguous_frameworks(detection)

      progress = ProgressReporter.new(verbose: config.verbose)
      test_suite = build_test_suite(config, detection, progress)
      run = MutationRun.new(config: config, test_suite: test_suite)
      run_mutations(run, test_suite, config, progress) { interrupted }

      run.finished_at = Time.now
      run.interrupted = interrupted
      Reporter.new(run).report

      return EXIT_INTERRUPTED if interrupted

      run.exit_code
    end

    # FR-002/SC-003: when both frameworks are present and none was forced
    # explicitly, the choice must be visible, never silent.
    def warn_ambiguous_frameworks(detection)
      return unless detection.ambiguous_frameworks

      warn "mutaterb: detected both RSpec and Minitest — using #{detection.test_framework} " \
           "(force one explicitly with --framework)"
    end

    def build_test_suite(config, detection, progress)
      test_runner = TestRunner.new(config: config, project_type: detection.project_type,
                                   framework: detection.test_framework)
      progress.start_baseline
      baseline_examples = test_runner.run_baseline(detection.test_files)
      progress.finish_baseline
      TestSuite.from_baseline(project_type: detection.project_type, framework: detection.test_framework,
                              baseline_examples: baseline_examples)
    end

    def run_mutations(run, test_suite, config, progress)
      mutator = Mutator.new(config: config, test_suite: test_suite)
      total = mutator.total_mutants
      if total.zero?
        warn "mutaterb: no mutants to run for the given scope"
        return
      end

      progress.start_mutants(total)
      mutator.each_mutant do |mutant|
        run.add_mutant(mutant)
        progress.mutant_finished(mutant)
        break if yield
      end
      progress.finish_mutants
    end
  end
end
