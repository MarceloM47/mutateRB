# frozen_string_literal: true

require "spec_helper"

RSpec.describe MutateRB::TestAdapters::MinitestAdapter do
  describe ".command_for" do
    it "runs a single file directly for a plain Ruby project" do
      command = described_class.command_for(["test/foo_test.rb"], project_type: :ruby)

      expect(command).to eq("echo @@MUTATERB_FILE@@test/foo_test.rb && " \
                            "bundle exec ruby -Itest -Ilib test/foo_test.rb -v")
    end

    it "joins multiple files with ; so TestRunner still spawns one process" do
      command = described_class.command_for(["test/a_test.rb", "test/b_test.rb"], project_type: :ruby)

      expect(command).to include(" ; ")
      expect(command).to include("test/a_test.rb")
      expect(command).to include("test/b_test.rb")
    end

    # Regression: a failing/erroring test in one file makes `ruby`/`bin/rails test` exit
    # non-zero — the normal case for a real project's baseline. Joining with `&&` used to let
    # that non-zero exit short-circuit the rest of the shell command, silently dropping every
    # file after the first failure from the baseline (never even echoing its FILE_MARKER).
    it "still runs every file's command even when an earlier one exits non-zero" do
      command = described_class.command_for(["test/a_test.rb", "test/b_test.rb"], project_type: :ruby)
      raw = `#{command.gsub("bundle exec ruby -Itest -Ilib test/a_test.rb -v", "false")} 2>/dev/null`

      expect(raw).to include("@@MUTATERB_FILE@@test/b_test.rb")
    end

    it "uses bin/rails test for a Rails project" do
      command = described_class.command_for(["test/models/user_test.rb"], project_type: :rails)

      expect(command).to include("bin/rails test test/models/user_test.rb -v")
    end
  end

  describe ".parse" do
    it "parses passed, failed, and error lines into example hashes" do
      raw = <<~OUT
        Run options: -v --seed 1

        # Running:

        FooTest#test_add = 0.01 s = .
        FooTest#test_fails = 0.02 s = F
        FooTest#test_raises = 0.03 s = E

        4 runs, 3 assertions, 1 failures, 1 errors, 0 skips
      OUT

      result = described_class.parse(raw, files: ["test/foo_test.rb"])

      expect(result[:status]).to eq(:completed)
      expect(result[:examples]).to contain_exactly(
        { id: "FooTest#test_add", description: "FooTest#test_add", file_path: "test/foo_test.rb",
          status: :passed, duration: 0.01 },
        { id: "FooTest#test_fails", description: "FooTest#test_fails", file_path: "test/foo_test.rb",
          status: :failed, duration: 0.02 },
        { id: "FooTest#test_raises", description: "FooTest#test_raises", file_path: "test/foo_test.rb",
          status: :failed, duration: 0.03 }
      )
    end

    it "excludes skipped tests instead of counting them as passed or failed" do
      raw = "FooTest#test_skipped = 0.00 s = S\n"

      result = described_class.parse(raw, files: ["test/foo_test.rb"])

      expect(result[:examples]).to be_empty
    end

    it "attributes each example to the file named by the preceding marker line" do
      raw = <<~OUT
        @@MUTATERB_FILE@@test/a_test.rb
        ATest#test_one = 0.01 s = .
        @@MUTATERB_FILE@@test/b_test.rb
        BTest#test_two = 0.01 s = .
      OUT

      result = described_class.parse(raw, files: ["test/a_test.rb", "test/b_test.rb"])

      expect(result[:examples].map { |e| e[:file_path] }).to eq(["test/a_test.rb", "test/b_test.rb"])
    end
  end
end
