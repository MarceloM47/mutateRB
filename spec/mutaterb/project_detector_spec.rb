# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe MutateRB::ProjectDetector do
  def make_project(rails: false)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "spec"))
      File.write(File.join(dir, "spec", "foo_spec.rb"), "RSpec.describe('x') {}")
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
      expect(detection.spec_files).to contain_exactly(File.join(dir, "spec", "foo_spec.rb"))
    end
  end

  it "finds no tests in an empty directory" do
    Dir.mktmpdir do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.spec_files).to be_empty
    end
  end
end
