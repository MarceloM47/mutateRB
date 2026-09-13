# frozen_string_literal: true

module MutateRB
  module MutationOperators
    # Flips a literal `true`/`false`.
    class BooleanLiteralOperator < BaseOperator
      def self.operator_type = :boolean_literal

      def self.applicable?(node)
        %i[TRUE FALSE].include?(node.type)
      end

      def self.replacement_for(_node, fragment)
        fragment == "true" ? "false" : "true"
      end
    end
  end
end
