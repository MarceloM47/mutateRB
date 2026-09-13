# frozen_string_literal: true

require "json"
require "time"

module MutateRB
  # Prints the console summary (FR-006) and, if configured, exports the same
  # result to JSON (FR-015, contracts/json-report-schema.md).
  class Reporter
    def initialize(run)
      @run = run
    end

    def report
      print_console
      write_json if run.config.json_output_path
    end

    private

    attr_reader :run

    def print_console
      summary = run.summary
      puts "MutateRB — #{summary[:total_mutants]} mutaciones: " \
           "#{summary[:killed]} killed, #{summary[:survived]} survived, #{summary[:errors]} errores"
      print_baseline_broken
      print_survived
    end

    def print_baseline_broken
      broken = run.baseline_broken_tests
      return if broken.empty?

      puts "Tests ya rotos antes de mutar (excluidos del conteo): #{broken.size}"
      broken.each { |t| puts "  - #{t.id} #{t.description}" }
    end

    def print_survived
      survived = run.survived_mutants
      return if survived.empty?

      puts "\nMutaciones survived (tests débiles):"
      survived.each do |mutant|
        related = mutant.related_tests.map(&:id).join(", ")
        puts "  - #{mutant.file_path}:#{mutant.line} [#{mutant.operator_type}] " \
             "'#{mutant.original_fragment}' -> '#{mutant.mutated_fragment}' (tests: #{related})"
      end
    end

    def write_json
      File.write(run.config.json_output_path, JSON.pretty_generate(to_h))
    end

    def to_h
      {
        mutaterb_version: MutateRB::VERSION,
        started_at: run.started_at.utc.iso8601,
        finished_at: run.finished_at&.utc&.iso8601,
        interrupted: run.interrupted,
        config: config_h,
        summary: run.summary,
        baseline_broken_tests: run.baseline_broken_tests.map { |t| test_case_h(t) },
        survived_mutants: run.survived_mutants.map { |m| mutant_h(m) },
        exit_code: run.exit_code
      }
    end

    def config_h
      c = run.config
      {
        target_dir: c.target_dir,
        include_paths: c.include_paths,
        exclude_paths: c.exclude_paths,
        strictness: c.strictness.to_s,
        mutation_types: c.mutation_types.map(&:to_s),
        exit_on_survivors: c.exit_on_survivors
      }
    end

    def mutant_h(mutant)
      {
        id: mutant.id,
        operator_type: mutant.operator_type.to_s,
        file_path: mutant.file_path,
        line: mutant.line,
        original_fragment: mutant.original_fragment,
        mutated_fragment: mutant.mutated_fragment,
        related_tests: mutant.related_tests.map { |t| test_case_h(t) }
      }
    end

    def test_case_h(test_case)
      { id: test_case.id, description: test_case.description }
    end
  end
end
