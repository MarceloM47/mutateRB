# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "securerandom"

RSpec.describe MutateRB::MutationRun do
  let(:config) { MutateRB::Config.new(target_dir: Dir.mktmpdir) }
  let(:broken_test) { MutateRB::TestCase.new(id: "b1", description: "roto", file_path: "spec/b_spec.rb", baseline_status: :failed, baseline_duration_seconds: 0.1) }
  let(:ok_test) { MutateRB::TestCase.new(id: "t1", description: "ok", file_path: "spec/a_spec.rb", baseline_status: :passed, baseline_duration_seconds: 0.1) }
  let(:test_suite) { MutateRB::TestSuite.new(project_type: :ruby, test_cases: [broken_test, ok_test]) }
  let(:run) { described_class.new(config: config, test_suite: test_suite) }

  def make_mutant(status:, kill_reason: nil)
    mutant = MutateRB::Mutant.new(id: SecureRandom.hex(4), operator_type: :boolean_literal, file_path: "lib/a.rb",
                                  line: 1, column_range: 0...4, original_fragment: "true", mutated_fragment: "false")
    mutant.finish!(status: status, kill_reason: kill_reason)
    mutant
  end

  it "excluye los tests base rotos del resumen y los expone aparte" do
    expect(run.baseline_broken_tests).to eq([broken_test])
  end

  it "calcula el resumen de killed/survived/errors" do
    run.add_mutant(make_mutant(status: :killed, kill_reason: :assertion_failure))
    run.add_mutant(make_mutant(status: :survived))
    run.add_mutant(make_mutant(status: :error))

    expect(run.summary).to include(total_mutants: 3, killed: 1, survived: 1, errors: 1)
  end

  it "survived? es true si hay al menos un mutante survived" do
    run.add_mutant(make_mutant(status: :killed, kill_reason: :timeout))
    expect(run.survived?).to be false

    run.add_mutant(make_mutant(status: :survived))
    expect(run.survived?).to be true
  end

  it "exit_code es 1 por defecto si hay survived, 0 si exit_on_survivors es false" do
    run.add_mutant(make_mutant(status: :survived))
    expect(run.exit_code).to eq(1)

    config.exit_on_survivors = false
    expect(run.exit_code).to eq(0)
  end
end
