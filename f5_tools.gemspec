# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'f5_tools/version'

Gem::Specification.new do |spec|
  spec.name          = 'f5_tools'
  spec.version       = F5_Tools::VERSION
  spec.authors       = ['Ben Congdon']
  spec.email         = ['ben.congdon@smartsheet.com']

  spec.summary       = 'F5Tools'
  spec.license       = 'Apache-2.0'
  spec.homepage      = 'https://github.com/smartsheet'
  spec.description   = 'Diff generation and configuration management tool for F5 load balancers'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'nil'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = 'f5tools'
  spec.require_paths = ['lib']

  spec.add_dependency 'netaddr', '~> 1.5', '>= 1.5.1'
  spec.add_dependency 'thor', '~> 0.19.1'
  spec.add_dependency 'rubysl-resolv', '~> 2.1', '>= 2.1.2'
  spec.add_dependency 'colorize', '~> 0.7.7'
  spec.add_dependency 'highline', '~> 1.7', '>= 1.7.8'
  spec.add_dependency 'net-scp', '~> 1.2'
  spec.add_dependency 'table_print', '~> 1.5', '>= 1.5.6'
  spec.add_dependency 'ipaddress', '~> 0.8', '>= 0.8.3'
  spec.add_dependency 'liquid', '~> 3.0', '>= 3.0.6'
  spec.add_dependency 'apipie-bindings', '0.0.8'
  spec.add_dependency 'diffy', '~> 3.1', '3.1.0'

  spec.add_development_dependency 'minitest', '5.8.4'
  spec.add_development_dependency 'rake', '~> 11.2'
  spec.add_development_dependency 'simplecov', '~> 0.11.2'
  spec.add_development_dependency 'yard', '~> 0.9', '>= 0.9.5'
end
