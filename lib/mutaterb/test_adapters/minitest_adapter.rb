# frozen_string_literal: true

require "shellwords"

module MutateRB
  module TestAdapters
    # Builds a Minitest invocation and parses its native `--verbose` output —
    # no added dependency in the target project (FR-009, research.md #2/#4).
    #
    # Minitest's own runner only knows how to run one file's worth of tests
    # per process, and its verbose line format doesn't name the source file,
    # so this adapter spawns one process per file (joined with `&&` into a
    # single shell command, so TestRunner still only tracks one pid) and
    # emits a marker line between them to attribute each parsed example back
    # to the file it came from.
    class MinitestAdapter
      LINE_PATTERN = /^(\S+)\s*=\s*([\d.]+)\s*s\s*=\s*([.FES])/
      FILE_MARKER = "@@MUTATERB_FILE@@"

      # Files are joined with `;`, not `&&`: `bin/rails test`/`ruby` exits non-zero whenever a
      # test fails or errors, which is the normal case for a real project's suite — `&&` would
      # silently stop the whole chain at the first failing file, dropping every file after it
      # from the baseline. Nothing here reads the shell's exit status (TestRunner classifies
      # purely from parsed output), so running every file regardless is safe.
      def self.command_for(files, project_type:)
        files.map { |file| "echo #{FILE_MARKER}#{Shellwords.escape(file)} && #{run_one(file, project_type)}" }
             .join(" ; ")
      end

      def self.run_one(file, project_type)
        runner = project_type == :rails ? "bin/rails test" : "bundle exec ruby -Itest -Ilib"
        "#{runner} #{Shellwords.escape(file)} -v"
      end
      private_class_method :run_one

      def self.parse(raw, files: [])
        current_file = files.first
        examples = []
        raw.each_line do |line|
          if (marker = line[/\A#{Regexp.escape(FILE_MARKER)}(.+)/, 1])
            current_file = marker.strip
            next
          end

          append_example(examples, line, current_file)
        end
        { status: :completed, examples: examples }
      end

      def self.append_example(examples, line, file)
        match = line.match(LINE_PATTERN)
        return unless match

        result_char = match[3]
        return if result_char == "S" # skipped: excluded, not passed/failed (research.md #2)

        examples << {
          id: match[1],
          description: match[1],
          file_path: file,
          status: result_char == "." ? :passed : :failed,
          duration: match[2].to_f
        }
      end
      private_class_method :append_example
    end
  end
end
