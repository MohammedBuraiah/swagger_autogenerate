# frozen_string_literal: true

require_relative "lib/swagger_autogenerate/version"

Gem::Specification.new do |spec|
  spec.name = "swagger_autogenerate"
  spec.version = SwaggerAutogenerate::VERSION
  spec.authors = ["MohammedBuraiah"]
  spec.email = ["mohammed.buraiah.1996@gmail.com"]

  spec.summary = "Generate OpenAPI/Swagger YAML from Rails request specs for rswag"
  spec.description = "Automatically builds Swagger YAML from RSpec request/controller examples. Works with rswag-api and rswag-ui."
  spec.homepage = "https://github.com/MohammedBuraiah/swagger_autogenerate"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/MohammedBuraiah/swagger_autogenerate"
  spec.metadata["changelog_uri"] = "https://github.com/MohammedBuraiah/swagger_autogenerate/blob/master/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "examples/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md", "CODE_OF_CONDUCT.md", "sig/**/*"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 5.2"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
