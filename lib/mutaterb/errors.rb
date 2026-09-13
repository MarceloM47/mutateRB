# frozen_string_literal: true

module MutateRB
  # Raised when the config file or CLI flags fail validation (FR-011).
  class ConfigError < StandardError; end

  # Raised when a mutation cannot be applied or reverted safely.
  class MutationError < StandardError; end
end
