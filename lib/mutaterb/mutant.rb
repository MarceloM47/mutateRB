# frozen_string_literal: true

module MutateRB
  # A single mutation applied to one location of a source file.
  #
  # Status starts at :pending and transitions exactly once to :killed,
  # :survived or :error (data-model.md).
  class Mutant
    VALID_STATUSES = %i[pending killed survived error].freeze
    VALID_KILL_REASONS = %i[assertion_failure timeout].freeze

    attr_reader :id, :operator_type, :file_path, :line, :column_range,
                :original_fragment, :mutated_fragment, :status, :kill_reason,
                :related_tests, :failing_tests, :error_message

    def initialize(id:, operator_type:, file_path:, line:, column_range:,
                   original_fragment:, mutated_fragment:)
      raise ArgumentError, "id must be a String" unless id.is_a?(String)
      raise ArgumentError, "operator_type must be a Symbol" unless operator_type.is_a?(Symbol)
      raise ArgumentError, "file_path must be a String" unless file_path.is_a?(String)
      raise ArgumentError, "line must be an Integer" unless line.is_a?(Integer)
      raise ArgumentError, "column_range must be a Range" unless column_range.is_a?(Range)

      @id = id
      @operator_type = operator_type
      @file_path = file_path
      @line = line
      @column_range = column_range
      @original_fragment = original_fragment
      @mutated_fragment = mutated_fragment
      @status = :pending
      @kill_reason = nil
      @related_tests = []
      @failing_tests = []
      @error_message = nil
    end

    def related_tests=(test_cases)
      @related_tests = Array(test_cases)
    end

    # Records the single, final outcome of running this mutant (FR-004).
    def finish!(status:, kill_reason: nil, failing_tests: [], error_message: nil)
      raise MutationError, "Mutant #{id} already finished as #{@status}" unless @status == :pending
      raise ArgumentError, "invalid status #{status.inspect}" unless VALID_STATUSES.include?(status)
      raise ArgumentError, "status must not be :pending" if status == :pending
      if kill_reason && !VALID_KILL_REASONS.include?(kill_reason)
        raise ArgumentError, "invalid kill_reason #{kill_reason.inspect}"
      end

      @status = status
      @kill_reason = kill_reason
      @failing_tests = Array(failing_tests)
      @error_message = error_message
      self
    end

    def killed? = status == :killed
    def survived? = status == :survived
    def error? = status == :error
  end
end
