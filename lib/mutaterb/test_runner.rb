# frozen_string_literal: true

require "timeout"
require "bundler"

module MutateRB
  # Runs the target project's own test suite as a subprocess (research.md #2
  # of feature 001): MutateRB never bundles its own RSpec/Minitest, it shells
  # out to the target project's own. The actual command and output parsing
  # are delegated to a framework-specific adapter (research.md #3 of feature
  # 004); this class owns spawning, timeouts, and killing hung processes.
  class TestRunner
    MIN_TIMEOUT_SECONDS = 5

    ADAPTERS = {
      rspec: TestAdapters::RspecAdapter,
      minitest: TestAdapters::MinitestAdapter
    }.freeze

    def initialize(config:, project_type:, framework: :rspec)
      @config = config
      @project_type = project_type
      @adapter = ADAPTERS.fetch(framework)
    end

    # Runs the given test files once, unmutated, and returns one Hash per
    # test example: { id:, description:, file_path:, status:, duration: }.
    # Used to build TestCase instances (FR-012's baseline_status) and as the
    # basis for the per-mutant timeout (FR-014).
    def run_baseline(files)
      spawn_test_command(files, timeout_seconds: nil).fetch(:examples, [])
    end

    # Runs the given test cases against a mutation. Timeout = 2x the slowest
    # related test's baseline duration, floor MIN_TIMEOUT_SECONDS (FR-014).
    # On timeout the child process is killed explicitly (research.md #3) so no
    # hung process survives the run.
    def run_for_mutant(test_cases)
      return { status: :error, examples: [] } if test_cases.empty?

      slowest_baseline = test_cases.filter_map(&:baseline_duration_seconds).max || 0
      timeout_seconds = [slowest_baseline * 2, MIN_TIMEOUT_SECONDS].max
      files = test_cases.map(&:file_path).uniq
      spawn_test_command(files, timeout_seconds: timeout_seconds)
    end

    private

    attr_reader :config, :project_type, :adapter

    # Runs inside Bundler.with_unbundled_env (research.md #2): when `mutaterb`
    # itself is invoked via `bundle exec`, BUNDLE_GEMFILE/RUBYOPT point at
    # MutateRB's own Gemfile and would otherwise leak into this child process.
    # Spawned in its own process group (pgroup: true) so that when the
    # adapter's command is a shell pipeline (Minitest's multi-file case joins
    # several invocations with `&&`), killing the group also reaches the
    # actual test process, not just the intermediate shell.
    def spawn_test_command(files, timeout_seconds:)
      env = project_type == :rails ? { "RAILS_ENV" => "test" } : {}
      command = adapter.command_for(files, project_type: project_type)
      stdout_read, stdout_write = IO.pipe
      pid = Bundler.with_unbundled_env do
        Process.spawn(env, command, out: stdout_write, err: File::NULL, pgroup: true,
                                    chdir: File.expand_path(config.target_dir))
      end
      stdout_write.close

      output = wait_with_timeout(pid, stdout_read, timeout_seconds, files)
      stdout_read.close unless stdout_read.closed?
      output
    end

    def wait_with_timeout(pid, stdout_read, timeout_seconds, files)
      if timeout_seconds
        Timeout.timeout(timeout_seconds) { read_and_wait(pid, stdout_read, files) }
      else
        read_and_wait(pid, stdout_read, files)
      end
    rescue Timeout::Error
      kill(pid)
      { status: :timeout, examples: [] }
    end

    def read_and_wait(pid, stdout_read, files)
      raw = stdout_read.read
      Process.wait(pid)
      adapter.parse(raw, files: files)
    end

    # Kills a hung child process group: TERM first, KILL if it ignores TERM
    # for 1s (research.md #3 of feature 001 — Timeout alone never touches the
    # child process). Signals the whole process group (negative pid) so a
    # shell-wrapped command's real child is reached too.
    def kill(pid)
      Process.kill("TERM", -pid)
      begin
        Timeout.timeout(1) { Process.wait(pid) }
      rescue Timeout::Error
        Process.kill("KILL", -pid)
        Process.wait(pid)
      end
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end
end
