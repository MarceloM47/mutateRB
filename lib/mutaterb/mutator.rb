# frozen_string_literal: true

module MutateRB
  # Orchestrates one mutation at a time: patches the file, runs the related
  # tests, classifies the outcome, and always restores the original file
  # (FR-003, FR-005, FR-010).
  class Mutator
    OPERATORS = {
      conditional_boundary: MutationOperators::ConditionalBoundaryOperator,
      boolean_literal: MutationOperators::BooleanLiteralOperator,
      nil_literal: MutationOperators::NilLiteralOperator,
      arithmetic_comparison: MutationOperators::ArithmeticComparisonOperator
    }.freeze

    def initialize(config:, test_suite:, test_runner: nil)
      @config = config
      @test_suite = test_suite
      @test_runner = test_runner || TestRunner.new(config: config, project_type: test_suite.project_type,
                                                   framework: test_suite.framework)
    end

    # Yields each finished Mutant, one at a time.
    def each_mutant
      source_files.each do |file|
        candidates_for(file).each { |mutant| yield run_one(mutant) }
      end
    end

    private

    attr_reader :config, :test_suite, :test_runner

    def source_files
      Dir.glob(File.join(config.target_dir, "**", "*.rb"))
         .reject { |f| f.include?("/spec/") || f.include?("/test/") }
         .select { |f| in_scope?(f) }
    end

    def in_scope?(file)
      included = config.include_paths.empty? || config.include_paths.any? { |p| file.start_with?(p) }
      excluded = config.exclude_paths.any? { |p| file.start_with?(p) }
      included && !excluded
    end

    def candidates_for(file)
      config.mutation_types.flat_map { |type| OPERATORS.fetch(type).candidates(file) }
    end

    def run_one(mutant)
      related = related_tests_for(mutant.file_path)
      mutant.related_tests = related

      begin
        original_content = File.read(mutant.file_path)
      rescue StandardError => e
        mutant.finish!(status: :error, error_message: "could not read #{mutant.file_path}: #{e.message}")
        return mutant
      end

      begin
        apply_patch(mutant, original_content)
        classify(mutant, related)
      rescue StandardError => e
        mutant.finish!(status: :error, error_message: e.message) if mutant.status == :pending
      ensure
        File.write(mutant.file_path, original_content)
      end

      mutant
    end

    def apply_patch(mutant, original_content)
      lines = original_content.lines
      line = lines[mutant.line - 1]
      range = mutant.column_range
      lines[mutant.line - 1] = line[0...range.begin] + mutant.mutated_fragment + line[range.end..]
      patched = lines.join

      begin
        RubyVM::AbstractSyntaxTree.parse(patched)
      rescue SyntaxError => e
        mutant.finish!(status: :error, error_message: "mutation produced invalid code: #{e.message}")
        return
      end

      File.write(mutant.file_path, patched)
    end

    def classify(mutant, related_tests)
      return unless mutant.status == :pending # apply_patch already marked :error

      if related_tests.empty?
        finish_inconclusive(mutant, "no related tests")
        return
      end

      result = test_runner.run_for_mutant(related_tests)
      case result[:status]
      when :timeout
        mutant.finish!(status: :killed, kill_reason: :timeout)
      when :error
        finish_inconclusive(mutant, "failed to run tests")
      else
        classify_from_examples(mutant, related_tests, result[:examples])
      end
    end

    # An inconclusive result (no tests exercised the mutation, or test
    # execution failed) does not prove the mutation is detected. With
    # strictness "high" this counts as evidence of weakness ("survived");
    # at other levels it is reported separately as "error" without
    # affecting the killed/survived count (US3/AC2, FR-008).
    def finish_inconclusive(mutant, message)
      if config.strictness == :high
        mutant.finish!(status: :survived)
      else
        mutant.finish!(status: :error, error_message: message)
      end
    end

    def classify_from_examples(mutant, related_tests, examples)
      failing_ids = examples.select { |e| e[:status] == :failed }.map { |e| e[:id] }
      failing_tests = related_tests.select { |t| failing_ids.include?(t.id) }
      if failing_tests.any?
        mutant.finish!(status: :killed, kill_reason: :assertion_failure, failing_tests: failing_tests)
      else
        mutant.finish!(status: :survived)
      end
    end

    # Convention-based coverage mapping: lib/foo/bar.rb -> spec/foo/bar_spec.rb
    # (or test/foo/bar_test.rb for Minitest, feature 004 research.md #5).
    # ponytail: no real coverage tracking yet; falls back to the whole suite
    # when no matching test file exists. Upgrade path: integrate SimpleCov
    # coverage data if this heuristic proves too coarse for real projects.
    def related_tests_for(source_file)
      mapped = mapped_test_file(source_file)
      matches = test_suite.test_cases.select { |t| t.file_path == mapped }
      matches = test_suite.test_cases.dup if matches.empty?
      matches.reject(&:baseline_broken?)
    end

    def mapped_test_file(source_file)
      relative = source_file.sub(%r{\A#{Regexp.escape(config.target_dir)}/?}, "")
      relative = relative.sub(%r{\A(lib|app)/}, "")
      if test_suite.framework == :minitest
        File.join(config.target_dir, "test", relative.sub(/\.rb\z/, "_test.rb"))
      else
        File.join(config.target_dir, "spec", relative.sub(/\.rb\z/, "_spec.rb"))
      end
    end
  end
end
