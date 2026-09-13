# frozen_string_literal: true

module MutateRB
  module MutationOperators
    # Replaces a literal `nil` with `false` — distinguishes code/tests that
    # depend on `nil` specifically (`.nil?`, `== nil`) from merely-falsy checks.
    #
    # ponytail: a bare `nil` as the sole/last expression of a method body is
    # optimized away by Ruby (implicit nil return, no NIL node at all), so it
    # is never mutated. Upgrade path: only relevant if that trailing-position
    # case turns out to matter in practice.
    class NilLiteralOperator < BaseOperator
      def self.operator_type = :nil_literal

      def self.applicable?(node)
        node.type == :NIL
      end

      def self.replacement_for(_node, _fragment)
        "false"
      end
    end
  end
end
