# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe MutateRB::Config do
  let(:dir) { Dir.mktmpdir }

  it "uses the data-model.md defaults when no config file exists" do
    config = described_class.load_file(File.join(dir, "nope.yml"))

    expect(config.target_dir).to eq(".")
    expect(config.strictness).to eq(:default)
    expect(config.mutation_types).to eq(described_class::ALL_MUTATION_TYPES)
    expect(config.exit_on_survivors).to be true
    expect(config.json_output_path).to be_nil
  end

  it "loads and validates .mutaterb.yml" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, <<~YAML)
      strictness: high
      mutation_types:
        - boolean_literal
    YAML

    config = described_class.load_file(path)

    expect(config.strictness).to eq(:high)
    expect(config.mutation_types).to eq([:boolean_literal])
  end

  it "rejects strictness outside {low, default, high}" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, "strictness: ultra\n")

    expect { described_class.load_file(path) }.to raise_error(MutateRB::ConfigError, /strictness/)
  end

  it "rejects mutation_types with an unregistered operator" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, "mutation_types:\n  - not_a_real_operator\n")

    expect { described_class.load_file(path) }.to raise_error(MutateRB::ConfigError, /unknown mutation_types/)
  end

  it "rejects a file that is not a YAML mapping" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, "- a\n- b\n")

    expect { described_class.load_file(path) }.to raise_error(MutateRB::ConfigError, /mapping/)
  end

  it "a CLI flag takes precedence over the config file value (FR-009)" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, "strictness: low\n")
    config = described_class.load_file(path)

    merged = config.merge_flags(strictness: :high)

    expect(merged.strictness).to eq(:high)
  end

  it "rejects nonexistent target_dir" do
    expect { described_class.new(target_dir: "/no/existe/seguro") }.to raise_error(MutateRB::ConfigError, /target_dir/)
  end
end
