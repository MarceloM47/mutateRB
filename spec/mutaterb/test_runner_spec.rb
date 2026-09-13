# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe MutateRB::TestRunner do
  before(:all) do
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@dir, "spec"))
    File.write(File.join(@dir, "spec", "hang_spec.rb"), <<~RUBY)
      RSpec.describe("hang") { it("cuelga") { loop {} } }
    RUBY
    File.write(File.join(@dir, "spec", "ok_spec.rb"), <<~RUBY)
      RSpec.describe("ok") { it("pasa") { expect(1).to eq(1) } }
    RUBY
    File.write(File.join(@dir, "Gemfile"), "source 'https://rubygems.org'\ngem 'rspec'\n")
    Dir.chdir(@dir) { system("bundle install --quiet", out: File::NULL, err: File::NULL) }
  end

  after(:all) { FileUtils.remove_entry(@dir) }

  let(:config) { MutateRB::Config.new(target_dir: @dir) }
  let(:runner) { described_class.new(config: config, project_type: :ruby) }

  it "mata el proceso colgado al vencer el timeout" do
    hang_spec_path = File.join(@dir, "spec", "hang_spec.rb")
    test_case = MutateRB::TestCase.new(id: "x", description: "cuelga", file_path: hang_spec_path,
                                       baseline_status: :passed, baseline_duration_seconds: 0.01)

    result = runner.run_for_mutant([test_case])

    expect(result[:status]).to eq(:timeout)
  end

  it "corre la corrida base y reporta duración por ejemplo" do
    examples = runner.run_baseline([File.join(@dir, "spec", "ok_spec.rb")])

    expect(examples.map { |e| e[:status] }).to eq([:passed])
    expect(examples.first[:duration]).to be_a(Float)
  end
end
