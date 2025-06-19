# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "pbbuilder"
  spec.version = "0.20.0"
  spec.authors = ["Bouke van der Bijl", "Julik Tarkhanov", "Stas Katkov", "Sebastian van Hesteren"]
  spec.email = ["julik@cheddar.me"]
  spec.homepage = "https://github.com/cheddar-me/pbbuilder"
  spec.summary = "Generate Protobuf messages with a simple DSL similar to JBuilder"
  spec.license = "MIT"

  spec.required_ruby_version = '>= 3.2'

  spec.files = `git ls-files`.split("\n")
  spec.test_files = `git ls-files -- test/*`.split("\n")

  spec.add_dependency "google-protobuf", ">= 3.25", "< 5.0"
  spec.add_dependency "activesupport"
  spec.add_development_dependency "m"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
end
