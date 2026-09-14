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

        opts.on("--dir PATH", "Target folder to analyze") { |v| flags[:target_dir] = v }
        opts.on("--include PATHS", "Subdirectories/files to include, comma-separated") do |v|
          flags[:include_paths] = v.split(",")
        end
        opts.on("--exclude PATHS", "Subdirectories/files to exclude, comma-separated") do |v|
          flags[:exclude_paths] = v.split(",")
        end
        opts.on("--strictness LEVEL", "low|default|high") { |v| flags[:strictness] = v.to_sym }
        opts.on("--framework FRAMEWORK", "auto|rspec|minitest") { |v| flags[:test_framework] = v.to_sym }
        opts.on("--mutation-types TYPES", "Mutation types to apply, comma-separated") do |v|
          flags[:mutation_types] = v.split(",").map(&:to_sym)
        end
        opts.on("--exit-zero", "Do not fail even if survived mutations exist") do
          flags[:exit_on_survivors] = false
        end
        opts.on("--json-output PATH", "Export summary to a JSON file") do |v|
          flags[:json_output_path] = v
        end
        opts.on("--config PATH", "Use a config file other than .mutaterb.yml") do |v|
          flags[:config_path] = v
        end
        opts.on("-h", "--help", "Show this help") do
          puts opts
          exit 0
        end
      end
    end
  end
end
