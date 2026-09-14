# frozen_string_literal: true

require "spec_helper"

RSpec.describe MutateRB::FlagParser do
  it "parses --dir, --strictness, and --mutation-types" do
    flags = described_class.parse(["--dir", "/tmp/x", "--strictness", "high", "--mutation-types",
                                   "boolean_literal,nil_literal"])

    expect(flags[:target_dir]).to eq("/tmp/x")
    expect(flags[:strictness]).to eq(:high)
    expect(flags[:mutation_types]).to eq(%i[boolean_literal nil_literal])
  end

  it "--exit-zero sets exit_on_survivors to false" do
    flags = described_class.parse(["--exit-zero"])

    expect(flags[:exit_on_survivors]).to be false
  end

  it "--verbose sets verbose to true" do
    flags = described_class.parse(["--verbose"])

    expect(flags[:verbose]).to be true
  end

  it "does not include a key if the flag was not passed (so the config file wins)" do
    flags = described_class.parse([])

    expect(flags).not_to have_key(:strictness)
    expect(flags).not_to have_key(:target_dir)
  end

  it "raises ConfigError for an unknown flag" do
    expect { described_class.parse(["--no-existe"]) }.to raise_error(MutateRB::ConfigError)
  end
end

RSpec.describe MutateRB::CLI do
  it "captures any unexpected error and returns the operational error exit code" do
    allow(MutateRB::ProjectDetector).to receive(:new).and_raise(StandardError, "unexpected boom")

    exit_code = nil
    expect { exit_code = described_class.new.run([]) }.not_to raise_error
    expect(exit_code).to eq(MutateRB::CLI::EXIT_OPERATIONAL_ERROR)
  end
end
