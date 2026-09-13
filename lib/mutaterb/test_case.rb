# frozen_string_literal: true

module MutateRB
  # A single test detected in the target project (data-model.md).
  class TestCase
    VALID_BASELINE_STATUSES = %i[passed failed].freeze

    attr_reader :id, :description, :file_path
    attr_accessor :baseline_status, :baseline_duration_seconds

    def initialize(id:, description:, file_path:, baseline_status: nil,
                   baseline_duration_seconds: nil)
      raise ArgumentError, "id must be a String" unless id.is_a?(String)
      raise ArgumentError, "file_path must be a String" unless file_path.is_a?(String)
      if baseline_status && !VALID_BASELINE_STATUSES.include?(baseline_status)
        raise ArgumentError, "invalid baseline_status #{baseline_status.inspect}"
      end

      @id = id
      @description = description.to_s
      @file_path = file_path
      @baseline_status = baseline_status
      @baseline_duration_seconds = baseline_duration_seconds
    end

    def baseline_broken? = baseline_status == :failed
  end
end
