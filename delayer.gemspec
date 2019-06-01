# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'delayer/version'

Gem::Specification.new do |spec|
  spec.name          = "delayer"
  spec.version       = Delayer::VERSION
  spec.authors       = ["Toshiaki Asai"]
  spec.email         = ["toshi.alternative@gmail.com"]
  spec.description   = %q{Delay the processing}
  spec.summary       = %q{Delay the processing}
  spec.homepage      = "https://github.com/toshia/delayer"
  spec.license       = "MIT"
  spec.required_ruby_version = '>= 2.4.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", '>= 12.3.2'
  spec.add_development_dependency "test-unit", '>= 3.3.3', '< 4.0'
end
