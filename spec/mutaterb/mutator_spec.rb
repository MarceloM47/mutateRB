# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe MutateRB::Mutator do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      FileUtils.mkdir_p(File.join(dir, "lib"))
      FileUtils.mkdir_p(File.join(dir, "spec"))
      @source_path = File.join(dir, "lib", "sample.rb")
      File.write(@source_path, "class Sample\n  def adult?(age)\n    age >= 18\n  end\nend\n")
      example.run
    end
  end

  let(:config) { MutateRB::Config.new(target_dir: @dir) }
  let(:test_case) { MutateRB::TestCase.new(id: "spec/sample_spec.rb[1:1]", description: "x", file_path: File.join(@dir, "spec", "sample_spec.rb"), baseline_status: :passed, baseline_duration_seconds: 0.01) }
  let(:test_suite) { MutateRB::TestSuite.new(project_type: :ruby, test_cases: [test_case]) }

  def original_content
    File.read(@source_path)
  end

  it "restaura el archivo original después de una mutación survived" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :completed,
                                                              examples: [{
                                                                id: test_case.id, status: :passed, duration: 0.01
                                                              }])
    before = original_content

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:survived) }

    expect(original_content).to eq(before)
  end

  it "restaura el archivo original cuando el test runner lanza una excepción inesperada" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_raise(StandardError, "boom")
    before = original_content

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:error) }

    expect(original_content).to eq(before)
  end

  it "marca la mutación como killed cuando el test relacionado falla" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :completed,
                                                              examples: [{
                                                                id: test_case.id, status: :failed, duration: 0.01
                                                              }])

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:killed) }
  end

  it "marca la mutación como killed by timeout cuando el test runner reporta timeout" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :timeout, examples: [])

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant do |mutant|
      expect(mutant.status).to eq(:killed)
      expect(mutant.kill_reason).to eq(:timeout)
    end
  end

  it "con estricticidad default, un resultado inconcluso se reporta como error" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :error, examples: [])

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:error) }
  end

  it "con estricticidad high, un resultado inconcluso cuenta como survived (US3/AC2)" do
    high_config = MutateRB::Config.new(target_dir: @dir, strictness: :high)
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :error, examples: [])

    mutator = described_class.new(config: high_config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:survived) }
  end
end
