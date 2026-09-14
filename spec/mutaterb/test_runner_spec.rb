# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "bundler"

RSpec.describe MutateRB::TestRunner do
  before(:all) do
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@dir, "spec"))
    File.write(File.join(@dir, "spec", "hang_spec.rb"), <<~RUBY)
      RSpec.describe("hang") { it("hangs") { loop {} } }
    RUBY
    File.write(File.join(@dir, "spec", "ok_spec.rb"), <<~RUBY)
      RSpec.describe("ok") { it("passes") { expect(1).to eq(1) } }
    RUBY
    File.write(File.join(@dir, "Gemfile"), "source 'https://rubygems.org'\ngem 'rspec'\n")
    # Isolate this nested `bundle install` from the outer process's own
    # Bundler env (same issue as research.md #2 in feature 001's TestRunner,
    # here in the spec's own fixture setup — see feature 003).
    Bundler.with_unbundled_env do
      Dir.chdir(@dir) { system("bundle install --quiet", out: File::NULL, err: File::NULL) }
    end
  end

  after(:all) { FileUtils.remove_entry(@dir) }

  let(:config) { MutateRB::Config.new(target_dir: @dir) }
  let(:runner) { described_class.new(config: config, project_type: :ruby) }

  it "kills the hung process when the timeout expires" do
    hang_spec_path = File.join(@dir, "spec", "hang_spec.rb")
    test_case = MutateRB::TestCase.new(id: "x", description: "hangs", file_path: hang_spec_path,
                                       baseline_status: :passed, baseline_duration_seconds: 0.01)

    result = runner.run_for_mutant([test_case])

    expect(result[:status]).to eq(:timeout)
  end

  it "runs the baseline and reports per-example duration" do
    examples = runner.run_baseline([File.join(@dir, "spec", "ok_spec.rb")])

    expect(examples.map { |e| e[:status] }).to eq([:passed])
    expect(examples.first[:duration]).to be_a(Float)
  end
end
