# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "pbbuilder"
  spec.version = "0.16.2"
  spec.authors = ["Bouke van der Bijl"]
  spec.email = ["bouke@cheddar.me"]
  spec.homepage = "https://github.com/cheddar-me/pbbuilder"
  spec.summary = "Generate Protobuf Messages with a simple DSL similar to JBuilder"
  spec.license = "MIT"

  spec.required_ruby_version = '>= 2.7'

  spec.files = `git ls-files`.split("\n")
  spec.test_files = `git ls-files -- test/*`.split("\n")

  spec.add_runtime_dependency "google-protobuf"
  # Rails has shipped an incompatible change in ActiveView, that was reverted in later versions.
  # @see https://github.com/rails/rails/pull/51023
  excluded_versions = ["7.1.0", "7.1.1", "7.1.2", "7.1.3"].map { |v| "!= #{v}" }
  spec.add_runtime_dependency "activesupport", *excluded_versions
  spec.add_development_dependency 'm'
  spec.add_development_dependency "pry"
end
