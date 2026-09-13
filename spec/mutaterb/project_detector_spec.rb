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

  it "detecta un proyecto Ruby puro" do
    make_project do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.project_type).to eq(:ruby)
    end
  end

  it "detecta un proyecto Rails por config/application.rb" do
    make_project(rails: true) do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.project_type).to eq(:rails)
    end
  end

  it "encuentra los archivos *_spec.rb bajo spec/" do
    make_project do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.spec_files).to contain_exactly(File.join(dir, "spec", "foo_spec.rb"))
    end
  end

  it "no encuentra tests en un directorio vacío" do
    Dir.mktmpdir do |dir|
      config = MutateRB::Config.new(target_dir: dir)
      detection = described_class.new(config).detect
      expect(detection.spec_files).to be_empty
    end
  end
end
