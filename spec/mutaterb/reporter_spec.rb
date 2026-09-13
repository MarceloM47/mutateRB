# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "securerandom"

RSpec.describe MutateRB::Reporter do
  let(:target_dir) { Dir.mktmpdir }
  let(:test_case) { MutateRB::TestCase.new(id: "t1", description: "es mayor de edad", file_path: "spec/a_spec.rb", baseline_status: :passed, baseline_duration_seconds: 0.1) }
  let(:test_suite) { MutateRB::TestSuite.new(project_type: :ruby, test_cases: [test_case]) }
  let(:config) { MutateRB::Config.new(target_dir: target_dir, json_output_path: File.join(target_dir, "report.json")) }
  let(:run) { MutateRB::MutationRun.new(config: config, test_suite: test_suite) }

  def survived_mutant
    mutant = MutateRB::Mutant.new(id: "m-1", operator_type: :conditional_boundary, file_path: "app/models/user.rb",
                                  line: 22, column_range: 0...9, original_fragment: ">", mutated_fragment: ">=")
    mutant.related_tests = [test_case]
    mutant.finish!(status: :survived)
    mutant
  end

  before do
    run.add_mutant(survived_mutant)
    run.finished_at = Time.now
  end

  it "imprime en consola el resumen y el detalle de las mutaciones survived" do
    expect { described_class.new(run).report }.to output(/1 mutaciones.*1 survived/m).to_stdout
  end

  it "exporta un JSON que cumple contracts/json-report-schema.md" do
    allow($stdout).to receive(:puts)
    described_class.new(run).report

    data = JSON.parse(File.read(config.json_output_path))

    expect(data["summary"]).to eq("total_mutants" => 1, "killed" => 0, "survived" => 1, "errors" => 0,
                                  "baseline_broken_tests" => 0)
    expect(data["survived_mutants"].first["file_path"]).to eq("app/models/user.rb")
    expect(data["survived_mutants"].first["line"]).to eq(22)
    expect(data["exit_code"]).to eq(1)
  end
end
