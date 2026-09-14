# frozen_string_literal: true

module MutateRB
  # Detects whether the target project is Ruby or Rails, which test framework
  # it uses (RSpec and/or Minitest), and locates its test files (FR-001,
  # FR-002, FR-003).
  class ProjectDetector
    Detection = Struct.new(:project_type, :test_framework, :test_files, :ambiguous_frameworks)

    def initialize(config)
      @config = config
    end

    def detect
      framework, ambiguous = resolve_test_framework
      Detection.new(project_type, framework, discover_test_files(framework), ambiguous)
    end

    private

    attr_reader :config

    def project_type
      rails_marker = File.join(config.target_dir, "config", "application.rb")
      rails_bin = File.join(config.target_dir, "bin", "rails")
      File.exist?(rails_marker) || File.exist?(rails_bin) ? :rails : :ruby
    end

    # research.md #1: an explicit config.test_framework always wins; otherwise
    # detect by which test files actually exist, RSpec winning when both do.
    def resolve_test_framework
      return [config.test_framework, false] unless config.test_framework == :auto

      has_rspec = test_files?(:rspec)
      has_minitest = test_files?(:minitest)
      return [:rspec, true] if has_rspec && has_minitest
      return [:minitest, false] if has_minitest && !has_rspec

      [:rspec, false]
    end

    def test_files?(framework)
      !Dir.glob(test_file_pattern(framework)).empty?
    end

    def discover_test_files(framework)
      apply_scope(Dir.glob(test_file_pattern(framework)))
    end

    def test_file_pattern(framework)
      if framework == :minitest
        File.join(config.target_dir, "test", "**", "*_test.rb")
      else
        File.join(config.target_dir, "spec", "**", "*_spec.rb")
      end
    end

    def apply_scope(files)
      files = files.select { |f| config.include_paths.any? { |p| f.start_with?(p) } } unless config.include_paths.empty?
      files.reject { |f| config.exclude_paths.any? { |p| f.start_with?(p) } }
    end
  end
end
