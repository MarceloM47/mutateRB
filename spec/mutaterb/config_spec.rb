# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe MutateRB::Config do
  let(:dir) { Dir.mktmpdir }

  it "usa los defaults de data-model.md cuando no hay archivo de config" do
    config = described_class.load_file(File.join(dir, "nope.yml"))

    expect(config.target_dir).to eq(".")
    expect(config.strictness).to eq(:default)
    expect(config.mutation_types).to eq(described_class::ALL_MUTATION_TYPES)
    expect(config.exit_on_survivors).to be true
    expect(config.json_output_path).to be_nil
  end

  it "carga y valida .mutaterb.yml" do
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

  it "rechaza un strictness fuera de {low, default, high}" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, "strictness: ultra\n")

    expect { described_class.load_file(path) }.to raise_error(MutateRB::ConfigError, /strictness/)
  end

  it "rechaza mutation_types con un operador no registrado" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, "mutation_types:\n  - not_a_real_operator\n")

    expect { described_class.load_file(path) }.to raise_error(MutateRB::ConfigError, /unknown mutation_types/)
  end

  it "rechaza un archivo que no es un mapping YAML" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, "- a\n- b\n")

    expect { described_class.load_file(path) }.to raise_error(MutateRB::ConfigError, /mapping/)
  end

  it "un flag de CLI tiene prioridad sobre el valor del archivo de config (FR-009)" do
    path = File.join(dir, ".mutaterb.yml")
    File.write(path, "strictness: low\n")
    config = described_class.load_file(path)

    merged = config.merge_flags(strictness: :high)

    expect(merged.strictness).to eq(:high)
  end

  it "rechaza target_dir inexistente" do
    expect { described_class.new(target_dir: "/no/existe/seguro") }.to raise_error(MutateRB::ConfigError, /target_dir/)
  end
end
