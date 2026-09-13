# frozen_string_literal: true

module MutateRB
  # The collection of tests detected for the target project (data-model.md).
  class TestSuite
    VALID_PROJECT_TYPES = %i[ruby rails].freeze

    attr_reader :framework, :project_type, :test_cases

    def initialize(project_type:, test_cases: [])
      unless VALID_PROJECT_TYPES.include?(project_type)
        raise ArgumentError,
              "invalid project_type #{project_type.inspect}"
      end

      @framework = :rspec
      @project_type = project_type
      @test_cases = Array(test_cases)
    end

    # Builds a TestSuite from the raw example hashes returned by
    # TestRunner#run_baseline (FR-012's baseline_status comes from here).
    def self.from_baseline(project_type:, baseline_examples:)
      test_cases = baseline_examples.map do |example|
        TestCase.new(
          id: example.fetch(:id),
          description: example.fetch(:description),
          file_path: example.fetch(:file_path),
          baseline_status: example.fetch(:status),
          baseline_duration_seconds: example.fetch(:duration)
        )
      end
      new(project_type: project_type, test_cases: test_cases)
    end

    def find(id)
      test_cases.find { |test_case| test_case.id == id }
    end

    def baseline_broken_tests
      test_cases.select(&:baseline_broken?)
    end
  end
end
