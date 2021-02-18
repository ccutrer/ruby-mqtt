require_relative 'lib/mqtt/version'

Gem::Specification.new do |gem|
  gem.name        = 'mqtt-ccutrer'
  gem.version     = MQTT::VERSION
  gem.author      = 'Cody Cutrer'
  gem.email       = 'cody@cutrer.us'
  gem.homepage    = 'http://github.com/ccutrer/ruby-mqtt'
  gem.summary     = 'Implementation of the MQTT protocol'
  gem.description = 'Pure Ruby gem that implements the MQTT protocol, a lightweight protocol for publish/subscribe messaging.'
  gem.license     = 'MIT'

  gem.files         = %w[README.md LICENSE.md NEWS.md] + Dir.glob('lib/**/*.rb')
  gem.test_files    = Dir.glob('spec/*_spec.rb')
  gem.executables   = %w[]
  gem.require_paths = %w[lib]

  gem.required_ruby_version = '>= 2.0.0'

  gem.add_development_dependency 'bundler',   '>= 1.11.2'
  gem.add_development_dependency 'rake',      '>= 10.2.2'
  gem.add_development_dependency 'yard',      '>= 0.9.11'
  gem.add_development_dependency 'rspec',     '>= 3.5.0'
  gem.add_development_dependency 'simplecov', '>= 0.9.2'
  gem.add_development_dependency 'rubocop',   '~> 0.48.0'
  gem.add_development_dependency 'byebug',    '~> 11.1'
end
