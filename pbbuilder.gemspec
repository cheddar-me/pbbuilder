Gem::Specification.new do |spec|
  spec.name = "pbbuilder"
  spec.version = "0.12.0"
  spec.authors = ["Bouke van der Bijl"]
  spec.email = ["bouke@cheddar.me"]
  spec.homepage = "https://github.com/cheddar-me/pbbuilder"
  spec.summary = "Generate Protobuf messages via a Builder-style DSL"
  spec.license = "MIT"

  s.required_ruby_version = '>= 2.2.2'

  spec.files = `git ls-files`.split("\n")
  spec.test_files = `git ls-files -- test/*`.split("\n")

  spec.add_dependency "google-protobuf", "~> 3.19", ">= 3.19.2"
end
