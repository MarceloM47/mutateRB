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

  it "restores the original file after a survived mutation" do
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

  it "restores the original file when the test runner raises an unexpected exception" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_raise(StandardError, "boom")
    before = original_content

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:error) }

    expect(original_content).to eq(before)
  end

  it "marks the mutation as killed when the related test fails" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :completed,
                                                              examples: [{
                                                                id: test_case.id, status: :failed, duration: 0.01
                                                              }])

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:killed) }
  end

  it "marks the mutation as killed by timeout when the test runner reports timeout" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :timeout, examples: [])

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant do |mutant|
      expect(mutant.status).to eq(:killed)
      expect(mutant.kill_reason).to eq(:timeout)
    end
  end

  it "with default strictness, an inconclusive result is reported as error" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :error, examples: [])

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:error) }
  end

  it "with high strictness, an inconclusive result counts as survived (US3/AC2)" do
    high_config = MutateRB::Config.new(target_dir: @dir, strictness: :high)
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :error, examples: [])

    mutator = described_class.new(config: high_config, test_suite: test_suite, test_runner: fake_runner)
    mutator.each_mutant { |mutant| expect(mutant.status).to eq(:survived) }
  end

  it "total_mutants matches the number of mutants each_mutant actually yields, memoized" do
    fake_runner = instance_double(MutateRB::TestRunner)
    allow(fake_runner).to receive(:run_for_mutant).and_return(status: :completed, examples: [])

    mutator = described_class.new(config: config, test_suite: test_suite, test_runner: fake_runner)
    total_before = mutator.total_mutants

    yielded = 0
    mutator.each_mutant { |_mutant| yielded += 1 }

    expect(total_before).to eq(yielded)
    expect(mutator.total_mutants).to eq(total_before)
  end
end
