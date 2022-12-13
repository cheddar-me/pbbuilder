Gem::Specification.new do |spec|
  spec.name = "pbbuilder"
  spec.version = "0.12.0"
  spec.authors = ["Bouke van der Bijl"]
  spec.email = ["bouke@cheddar.me"]
  spec.homepage = "https://github.com/cheddar-me/pbbuilder"
  spec.summary = "Generate Protobuf Messages with a simple DSL similar to JBuilder"
  spec.license = "MIT"

  spec.required_ruby_version = '>= 2.7'

  spec.files = `git ls-files`.split("\n")
  spec.test_files = `git ls-files -- test/*`.split("\n")

  spec.add_dependency "google-protobuf", "~> 3.19", ">= 3.19.2"
end
