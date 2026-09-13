# frozen_string_literal: true

require "json"
require "timeout"

module MutateRB
  # Runs the target project's own RSpec suite as a subprocess (research.md #2):
  # MutateRB never bundles its own RSpec, it shells out to `bundle exec rspec`
  # inside the target project so the project's own Gemfile.lock decides the
  # RSpec version.
  class TestRunner
    MIN_TIMEOUT_SECONDS = 5

    def initialize(config:, project_type:)
      @config = config
      @project_type = project_type
    end

    # Runs the given spec files once, unmutated, and returns one Hash per
    # RSpec example: { id:, description:, file_path:, status:, duration: }.
    # Used to build TestCase instances (FR-012's baseline_status) and as the
    # basis for the per-mutant timeout (FR-014).
    def run_baseline(spec_files)
      spawn_rspec(spec_files, timeout_seconds: nil).fetch(:examples, [])
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
      spawn_rspec(files, timeout_seconds: timeout_seconds)
    end

    private

    attr_reader :config, :project_type

    def spawn_rspec(files, timeout_seconds:)
      env = project_type == :rails ? { "RAILS_ENV" => "test" } : {}
      stdout_read, stdout_write = IO.pipe
      pid = Process.spawn(env, *rspec_command(files), out: stdout_write, err: File::NULL,
                                                      chdir: File.expand_path(config.target_dir))
      stdout_write.close

      output = wait_with_timeout(pid, stdout_read, timeout_seconds)
      stdout_read.close unless stdout_read.closed?
      output
    end

    def wait_with_timeout(pid, stdout_read, timeout_seconds)
      if timeout_seconds
        Timeout.timeout(timeout_seconds) { read_and_wait(pid, stdout_read) }
      else
        read_and_wait(pid, stdout_read)
      end
    rescue Timeout::Error
      kill(pid)
      { status: :timeout, examples: [] }
    end

    def read_and_wait(pid, stdout_read)
      raw = stdout_read.read
      Process.wait(pid)
      parse_output(raw)
    end

    # Kills a hung child process: TERM first, KILL if it ignores TERM for 1s
    # (research.md #3 — Timeout alone never touches the child process).
    def kill(pid)
      Process.kill("TERM", pid)
      begin
        Timeout.timeout(1) { Process.wait(pid) }
      rescue Timeout::Error
        Process.kill("KILL", pid)
        Process.wait(pid)
      end
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end

    def rspec_command(files)
      ["bundle", "exec", "rspec", "--format", "json", *files]
    end

    def parse_output(raw)
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
