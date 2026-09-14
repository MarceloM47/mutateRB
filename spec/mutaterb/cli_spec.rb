# frozen_string_literal: true

require "spec_helper"

RSpec.describe MutateRB::FlagParser do
  it "parsea --dir, --strictness y --mutation-types" do
    flags = described_class.parse(["--dir", "/tmp/x", "--strictness", "high", "--mutation-types",
                                   "boolean_literal,nil_literal"])

    expect(flags[:target_dir]).to eq("/tmp/x")
    expect(flags[:strictness]).to eq(:high)
    expect(flags[:mutation_types]).to eq(%i[boolean_literal nil_literal])
  end

  it "--exit-zero pone exit_on_survivors en false" do
    flags = described_class.parse(["--exit-zero"])

    expect(flags[:exit_on_survivors]).to be false
  end

  it "no incluye una clave si el flag no fue pasado (para que gane el config file)" do
    flags = described_class.parse([])

    expect(flags).not_to have_key(:strictness)
    expect(flags).not_to have_key(:target_dir)
  end

  it "levanta ConfigError ante un flag desconocido" do
    expect { described_class.parse(["--no-existe"]) }.to raise_error(MutateRB::ConfigError)
  end
end

RSpec.describe MutateRB::CLI do
  it "captura cualquier error inesperado y devuelve el exit code de error operativo" do
    allow(MutateRB::ProjectDetector).to receive(:new).and_raise(StandardError, "boom inesperado")

    exit_code = nil
    expect { exit_code = described_class.new.run([]) }.not_to raise_error
    expect(exit_code).to eq(MutateRB::CLI::EXIT_OPERATIONAL_ERROR)
  end
end
