# frozen_string_literal: true

require "yaml"

module MutateRB
  # Resolved options for a run, merging .mutaterb.yml and CLI flags
  # (flags win, FR-009). See contracts/config-schema.md for the file format.
  class Config
    ALL_MUTATION_TYPES = %i[conditional_boundary boolean_literal nil_literal arithmetic_comparison].freeze
    VALID_STRICTNESS = %i[low default high].freeze
    DEFAULT_FILE_NAME = ".mutaterb.yml"

    attr_accessor :target_dir, :include_paths, :exclude_paths, :strictness,
                  :mutation_types, :exit_on_survivors, :json_output_path

    def initialize(target_dir: ".", include_paths: [], exclude_paths: [],
                   strictness: :default, mutation_types: ALL_MUTATION_TYPES.dup,
                   exit_on_survivors: true, json_output_path: nil)
      @target_dir = target_dir
      @include_paths = include_paths
      @exclude_paths = exclude_paths
      @strictness = strictness
      @mutation_types = mutation_types
      @exit_on_survivors = exit_on_survivors
      @json_output_path = json_output_path
      validate!
    end

    def self.default
      new
    end

    # Loads .mutaterb.yml (or the path given by --config) if present, validates
    # it, and returns a Config with the file's values applied on top of the
    # defaults (FR-007). Returns Config.default if no file is present.
    def self.load_file(path = DEFAULT_FILE_NAME)
      return default unless File.exist?(path)

      raw = YAML.safe_load_file(path, permitted_classes: [Symbol], symbolize_names: false)
      raise ConfigError, "#{path} must contain a YAML mapping" unless raw.is_a?(Hash)

      new(**attributes_from_yaml(raw))
    rescue Psych::SyntaxError => e
      raise ConfigError, "#{path} is not valid YAML: #{e.message}"
    end

    def self.attributes_from_yaml(raw)
      known_keys = %w[target_dir include_paths exclude_paths strictness mutation_types
                      exit_on_survivors json_output_path]
      raw.each_key do |key|
        warn "mutaterb: ignoring unknown config key #{key.inspect}" unless known_keys.include?(key)
      end

      {
        target_dir: raw.fetch("target_dir", "."),
        include_paths: Array(raw["include_paths"]),
        exclude_paths: Array(raw["exclude_paths"]),
        strictness: raw.key?("strictness") ? symbolize(raw["strictness"], "strictness") : :default,
        mutation_types: if raw.key?("mutation_types")
                          Array(raw["mutation_types"]).map do |t|
                            symbolize(t, "mutation_types")
                          end
                        else
                          ALL_MUTATION_TYPES.dup
                        end,
        exit_on_survivors: raw.fetch("exit_on_survivors", true),
        json_output_path: raw["json_output_path"]
      }
    end
    private_class_method :attributes_from_yaml

    def self.symbolize(value, field)
      raise ConfigError, "#{field} must be a string" unless value.is_a?(String)

      value.to_sym
    end
    private_class_method :symbolize

    # Applies CLI flag overrides on top of this config, field by field
    # (FR-009: a flag always wins over the config file).
    def merge_flags(flags)
      merged = dup
      flags.each do |key, value|
        next if value.nil?

        merged.public_send("#{key}=", value)
      end
      merged.validate!
      merged
    end

    def validate!
      raise ConfigError, "target_dir must be a String" unless target_dir.is_a?(String)
      raise ConfigError, "target_dir #{target_dir.inspect} does not exist" unless Dir.exist?(target_dir)
      raise ConfigError, "include_paths must be an Array" unless include_paths.is_a?(Array)
      raise ConfigError, "exclude_paths must be an Array" unless exclude_paths.is_a?(Array)
      unless VALID_STRICTNESS.include?(strictness)
        raise ConfigError, "strictness must be one of #{VALID_STRICTNESS.join(', ')}, got #{strictness.inspect}"
      end
      raise ConfigError, "mutation_types must be an Array" unless mutation_types.is_a?(Array)

      unknown = mutation_types - ALL_MUTATION_TYPES
      raise ConfigError, "unknown mutation_types: #{unknown.join(', ')}" unless unknown.empty?
      raise ConfigError, "exit_on_survivors must be true or false" unless [true, false].include?(exit_on_survivors)

      return unless json_output_path

      parent = File.dirname(File.expand_path(json_output_path))
      raise ConfigError, "directory for json_output_path does not exist: #{parent}" unless Dir.exist?(parent)
    end
  end
end
