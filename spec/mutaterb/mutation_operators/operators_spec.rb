# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "MutateRB::MutationOperators" do
  def write_source(content)
    dir = Dir.mktmpdir
    path = File.join(dir, "sample.rb")
    File.write(path, content)
    path
  end

  it "ConditionalBoundaryOperator swaps > por >=" do
    path = write_source("def adult?(age)\n  age > 18\nend\n")
    mutants = MutateRB::MutationOperators::ConditionalBoundaryOperator.candidates(path)

    expect(mutants.map(&:mutated_fragment)).to include("age >= 18")
  end

  it "BooleanLiteralOperator flips true/false" do
    path = write_source("def enabled?\n  true\nend\n")
    mutants = MutateRB::MutationOperators::BooleanLiteralOperator.candidates(path)

    expect(mutants.map(&:mutated_fragment)).to eq(["false"])
  end

  it "NilLiteralOperator reemplaza nil por false" do
    # ponytail: un `nil` como única expresión final de un método no genera
    # nodo NIL en RubyVM::AbstractSyntaxTree (Ruby lo optimiza a un retorno
    # implícito) — se prueba con `nil` en posición no final, el caso común.
    path = write_source("def value\n  x = nil\n  x\nend\n")
    mutants = MutateRB::MutationOperators::NilLiteralOperator.candidates(path)

    expect(mutants.map(&:mutated_fragment)).to eq(["false"])
  end

  it "ArithmeticComparisonOperator swaps + por -" do
    path = write_source("def add(a, b)\n  a + b\nend\n")
    mutants = MutateRB::MutationOperators::ArithmeticComparisonOperator.candidates(path)

    expect(mutants.map(&:mutated_fragment)).to include("a - b")
  end

  it "produce mutantes que siguen siendo Ruby válido" do
    path = write_source("def adult?(age)\n  age >= 18\nend\n")
    mutants = MutateRB::MutationOperators::ConditionalBoundaryOperator.candidates(path)

    mutants.each do |mutant|
      lines = File.read(path).lines
      lines[mutant.line - 1] = lines[mutant.line - 1].dup.tap do |l|
        l[mutant.column_range] = mutant.mutated_fragment
      end
      expect { RubyVM::AbstractSyntaxTree.parse(lines.join) }.not_to raise_error
    end
  end
end
