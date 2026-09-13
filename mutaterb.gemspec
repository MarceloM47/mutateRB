# frozen_string_literal: true

require_relative "lib/mutaterb/version"

Gem::Specification.new do |spec|
  spec.name = "mutaterb"
  spec.version = MutateRB::VERSION
  spec.authors = ["MutateRB"]
  spec.summary = "Mutation testing CLI for Ruby and Ruby on Rails projects"
  spec.description = "Detects weak tests by mutating source code covered by an RSpec suite " \
                     "and checking whether the suite catches the mutation."
  spec.homepage = "https://github.com/mutaterb/mutaterb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "exe/*", "README*", "LICENSE*"]
  spec.bindir = "exe"
  spec.executables = ["mutaterb"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.65"
  spec.metadata["rubygems_mfa_required"] = "true"
end
