# frozen_string_literal: true

module MutateRB
  # Detects whether the target project is Ruby or Rails and locates its RSpec
  # files (FR-001, FR-002).
  class ProjectDetector
    Detection = Struct.new(:project_type, :spec_files)

    def initialize(config)
      @config = config
    end

    def detect
      Detection.new(project_type, discover_spec_files)
    end

    private

    attr_reader :config

    def project_type
      rails_marker = File.join(config.target_dir, "config", "application.rb")
      rails_bin = File.join(config.target_dir, "bin", "rails")
      File.exist?(rails_marker) || File.exist?(rails_bin) ? :rails : :ruby
    end

    def discover_spec_files
      pattern = File.join(config.target_dir, "spec", "**", "*_spec.rb")
      apply_scope(Dir.glob(pattern))
    end

    def apply_scope(files)
      files = files.select { |f| config.include_paths.any? { |p| f.start_with?(p) } } unless config.include_paths.empty?
      files.reject { |f| config.exclude_paths.any? { |p| f.start_with?(p) } }
    end
  end
end
