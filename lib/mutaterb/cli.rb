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
      # Constitution Principio V: ningún error puede salir sin capturar.
      # Cualquier fallo no previsto (detección de proyecto, corrida base,
      # etc.) se reporta de forma controlada en vez de propagar un backtrace
      # crudo (contracts/cli.md: exit 2 = error operativo, SC-005).
      warn "mutaterb: error inesperado: #{e.message}"
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
      if detection.spec_files.empty?
        warn "mutaterb: no se encontraron tests en #{config.target_dir}"
        return EXIT_OPERATIONAL_ERROR
      end

      test_suite = build_test_suite(config, detection)
      run = MutationRun.new(config: config, test_suite: test_suite)
      run_mutations(run, test_suite, config) { interrupted }

      run.finished_at = Time.now
      run.interrupted = interrupted
      Reporter.new(run).report

      return EXIT_INTERRUPTED if interrupted

      run.exit_code
    end

    def build_test_suite(config, detection)
      test_runner = TestRunner.new(config: config, project_type: detection.project_type)
      baseline_examples = test_runner.run_baseline(detection.spec_files)
      TestSuite.from_baseline(project_type: detection.project_type, baseline_examples: baseline_examples)
    end

    def run_mutations(run, test_suite, config)
      mutator = Mutator.new(config: config, test_suite: test_suite)
      mutator.each_mutant do |mutant|
        run.add_mutant(mutant)
        break if yield
      end
    end
  end
end
