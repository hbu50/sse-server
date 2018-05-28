# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sse/server/version'

Gem::Specification.new do |spec|
  spec.name          = "sse-server"
  spec.version       = Sse::Server::VERSION
  spec.authors       = ["Hossein Bukhamseen"]
  spec.email         = ["bukhamseen.h@gmail.com"]
  spec.description   = %q{A redis backed server sent event server}
  spec.summary       = %q{such gem}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", "~> 4.0"
  spec.add_dependency "sinatra"
  spec.add_dependency "connection_pool"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

end
