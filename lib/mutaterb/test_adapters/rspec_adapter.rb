# frozen_string_literal: true

require "json"
require "shellwords"

module MutateRB
  module TestAdapters
    # Builds the `bundle exec rspec` command and parses its `--format json`
    # output (extracted from TestRunner, research.md #3 of feature 004 —
    # MutateRB never bundles its own RSpec, it shells out to the target
    # project's own).
    class RspecAdapter
      def self.command_for(files, project_type:) # rubocop:disable Lint/UnusedMethodArgument
        "bundle exec rspec --format json #{Shellwords.join(files)}"
      end

      def self.parse(raw, files: []) # rubocop:disable Lint/UnusedMethodArgument
        data = JSON.parse(raw)
        examples = data.fetch("examples", []).map do |example|
          {
            id: example["id"],
            description: example["full_description"],
            file_path: example["file_path"],
            status: example["status"] == "passed" ? :passed : :failed,
            duration: example["run_time"].to_f
          }
        end
        { status: :completed, examples: examples }
      rescue JSON::ParserError
        { status: :error, examples: [] }
      end
    end
  end
end
