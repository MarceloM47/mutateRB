# frozen_string_literal: true

module MutateRB
  module MutationOperators
    # Swaps an arithmetic or equality operator for its common typo/off-by-logic
    # counterpart: + <-> -, * <-> /, == <-> !=.
    class ArithmeticComparisonOperator < BaseOperator
      SWAPS = { "+" => "-", "-" => "+", "*" => "/", "/" => "*", "==" => "!=", "!=" => "==" }.freeze

      def self.operator_type = :arithmetic_comparison

      def self.applicable?(node)
        node.type == :OPCALL && SWAPS.key?(node.children[1].to_s)
      end

      def self.replacement_for(node, fragment)
        op = node.children[1].to_s
        fragment.sub(op, SWAPS.fetch(op))
      end
    end
  end
end
