# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tofu/version'

Gem::Specification.new do |spec|
  spec.name          = "tofu"
  spec.version       = Tofu::VERSION
  spec.authors       = ["Masatoshi SEKI"]
  spec.email         = ["seki@ruby-lang.org"]

  spec.summary       = %q{tiny web-ui framework for me.}
  spec.description   = %q{tiny web-ui framework for plain WEBrick lovers}
  spec.homepage      = "https://github.com/seki/Tofu"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
end
