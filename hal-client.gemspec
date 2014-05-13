# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hal_client/version'

Gem::Specification.new do |spec|
  spec.name          = "hal-client"
  spec.version       = HalClient::VERSION
  spec.authors       = ["Peter Williams"]
  spec.email         = ["pezra@barelyenough.org"]
  spec.summary       = %q{Use HAL APIs easily}
  spec.description   = %q{An easy to use interface for REST APIs that use HAL.}
  spec.homepage      = "https://github.com/pezra/hal-client"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "http", "~> 0.6.1"
  spec.add_dependency "addressable", "~> 2.3"
  spec.add_dependency "multi_json", "~> 1.9"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake", "~> 10.1"
  spec.add_development_dependency "rspec", "~> 3.0.0.beta"
  spec.add_development_dependency "webmock", ["~> 1.17", ">= 1.17.4"]
  spec.add_development_dependency "rspec-collection_matchers"
end
