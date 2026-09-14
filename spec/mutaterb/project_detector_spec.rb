# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe MutateRB::ProjectDetector do
  def make_project(rails: false, rspec: true, minitest: false)
    Dir.mktmpdir do |dir|
      if rspec
        FileUtils.mkdir_p(File.join(dir, "spec"))
        File.write(File.join(dir, "spec", "foo_spec.rb"), "RSpec.describe('x') {}")
      end
      if minitest
        FileUtils.mkdir_p(File.join(dir, "test"))
        File.write(File.join(dir, "test", "foo_test.rb"), "class FooTest; end")
      end
      if rails
        FileUtils.mkdir_p(File.join(dir, "config"))
        File.write(File.join(dir, "config", "application.rb"), "")
      end
      yield dir
    end
  end

  it "detects a pure Ruby project" do
    make_project do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.project_type).to eq(:ruby)
    end
  end

  it "detects a Rails project via config/application.rb" do
    make_project(rails: true) do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.project_type).to eq(:rails)
    end
  end

  it "finds *_spec.rb files under spec/" do
    make_project do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.test_files).to contain_exactly(File.join(dir, "spec", "foo_spec.rb"))
    end
  end

  it "finds no tests in an empty directory" do
    Dir.mktmpdir do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.test_files).to be_empty
      expect(detection.test_framework).to eq(:rspec)
    end
  end

  it "detects Minitest when only test/ has files (FR-001)" do
    make_project(rspec: false, minitest: true) do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.test_framework).to eq(:minitest)
      expect(detection.test_files).to contain_exactly(File.join(dir, "test", "foo_test.rb"))
      expect(detection.ambiguous_frameworks).to be false
    end
  end

  it "prefers RSpec by default when both frameworks are present (FR-002)" do
    make_project(rspec: true, minitest: true) do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.test_framework).to eq(:rspec)
      expect(detection.ambiguous_frameworks).to be true
    end
  end

  it "lets an explicit test_framework override auto-detection (FR-003)" do
    make_project(rspec: true, minitest: true) do |dir|
      config = MutateRB::Config.new(target_dir: dir, test_framework: :minitest)
      detection = described_class.new(config).detect
      expect(detection.test_framework).to eq(:minitest)
      expect(detection.test_files).to contain_exactly(File.join(dir, "test", "foo_test.rb"))
      expect(detection.ambiguous_frameworks).to be false
    end
  end
end
