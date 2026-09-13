# frozen_string_literal: true

module MutateRB
  module MutationOperators
    # Walks a file's AST via RubyVM::AbstractSyntaxTree (research.md #1) and
    # turns each matching node into a Mutant, without reserializing the file:
    # only the exact node span gets patched as a text substitution.
    #
    # ponytail: multi-line expressions are skipped (first_lineno != last_lineno)
    # to keep the text-patch approach simple; revisit with the `parser` gem if
    # the operator catalog needs to mutate across line breaks.
    class BaseOperator
      class << self
        def operator_type
          raise NotImplementedError
        end

        def applicable?(_node)
          raise NotImplementedError
        end

        def replacement_for(_node, _fragment)
          raise NotImplementedError
        end

        def candidates(file_path)
          source = File.read(file_path)
          root = RubyVM::AbstractSyntaxTree.parse(source)
          lines = source.lines
          mutants = []
          walk(root) { |node| mutants << build_mutant(file_path, lines, node) if applicable?(node) }
          mutants.compact
        rescue SyntaxError
          []
        end

        private

        def walk(node, &block)
          return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

          block.call(node) if node.first_lineno == node.last_lineno
          node.children.each { |child| walk(child, &block) }
        end

        def build_mutant(file_path, lines, node)
          range = node.first_column...node.last_column
          original = lines[node.first_lineno - 1][range]
          return nil if original.nil?

          mutated = replacement_for(node, original)
          return nil if mutated.nil? || mutated == original

          Mutant.new(
            id: "#{file_path}:#{node.first_lineno}:#{range.begin}:#{operator_type}",
            operator_type: operator_type,
            file_path: file_path,
            line: node.first_lineno,
            column_range: range,
            original_fragment: original,
            mutated_fragment: mutated
          )
        end
      end
    end
  end
end
