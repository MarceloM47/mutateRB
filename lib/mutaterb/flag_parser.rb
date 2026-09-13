# frozen_string_literal: true

require "optparse"

module MutateRB
  # Parses CLI flags into the hash consumed by Config#merge_flags (FR-008,
  # contracts/cli.md). Only flags actually passed appear in the result, so
  # CLI flags win over the config file field by field (FR-009).
  class FlagParser
    def self.parse(argv)
      new.parse(argv)
    end

    def parse(argv)
      flags = { config_path: Config::DEFAULT_FILE_NAME }

      parser = build_parser(flags)
      parser.parse!(argv.dup)
      flags
    rescue OptionParser::ParseError => e
      raise ConfigError, e.message
    end

    private

    def build_parser(flags)
      OptionParser.new do |opts|
        opts.banner = "Usage: mutaterb [flags]"

        opts.on("--dir PATH", "Carpeta objetivo a analizar") { |v| flags[:target_dir] = v }
        opts.on("--include PATHS", "Subcarpetas/archivos a incluir, separados por coma") do |v|
          flags[:include_paths] = v.split(",")
        end
        opts.on("--exclude PATHS", "Subcarpetas/archivos a excluir, separados por coma") do |v|
          flags[:exclude_paths] = v.split(",")
        end
        opts.on("--strictness LEVEL", "low|default|high") { |v| flags[:strictness] = v.to_sym }
        opts.on("--mutation-types TYPES", "Tipos de mutación, separados por coma") do |v|
          flags[:mutation_types] = v.split(",").map(&:to_sym)
        end
        opts.on("--exit-zero", "No fallar aunque haya mutaciones survived") do
          flags[:exit_on_survivors] = false
        end
        opts.on("--json-output PATH", "Exporta el resumen a un archivo JSON") do |v|
          flags[:json_output_path] = v
        end
        opts.on("--config PATH", "Usa un archivo de config distinto de .mutaterb.yml") do |v|
          flags[:config_path] = v
        end
        opts.on("-h", "--help", "Muestra esta ayuda") do
          puts opts
          exit 0
        end
      end
    end
  end
end
