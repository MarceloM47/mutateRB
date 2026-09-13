# frozen_string_literal: true

module MutateRB
  module MutationOperators
    # Swaps a comparison operator for its off-by-one boundary: < <-> <=, > <-> >=.
    class ConditionalBoundaryOperator < BaseOperator
      SWAPS = { "<" => "<=", "<=" => "<", ">" => ">=", ">=" => ">" }.freeze

      def self.operator_type = :conditional_boundary

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
