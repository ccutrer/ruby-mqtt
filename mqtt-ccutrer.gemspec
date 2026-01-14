# frozen_string_literal: true

require_relative 'lib/mqtt/version'

Gem::Specification.new do |gem|
  gem.name          = 'mqtt-ccutrer'
  gem.version       = MQTT::VERSION
  gem.author        = 'Cody Cutrer'
  gem.email         = 'cody@cutrer.us'
  gem.homepage      = 'http://github.com/ccutrer/ruby-mqtt'
  gem.summary       = 'Implementation of the MQTT protocol'
  gem.description   = <<-DESCRIPTION
  Pure Ruby gem that implements the MQTT protocol, a lightweight protocol for
  publish/subscribe messaging.
  DESCRIPTION
  gem.license       = 'MIT'
  gem.files         = %w[README.md LICENSE.md NEWS.md] + Dir.glob('lib/**/*.rb')
  gem.test_files    = Dir.glob('spec/*_spec.rb')
  gem.executables   = %w[]
  gem.require_paths = %w[lib]

  gem.required_ruby_version = '>= 2.5'

  gem.add_dependency 'logger', '~> 1.7'

  gem.add_development_dependency 'bundler',       '>= 1.11.2'
  gem.add_development_dependency 'byebug',        '~> 11.1'
  gem.add_development_dependency 'rake',          '>= 10.2.2'
  gem.add_development_dependency 'rspec',         '>= 3.5.0'
  gem.add_development_dependency 'rubocop',       '~> 1.10'
  gem.add_development_dependency 'rubocop-rake',  '~> 0.5'
  gem.add_development_dependency 'rubocop-rspec', '~> 2.2'
  gem.add_development_dependency 'simplecov',     '>= 0.9.2'
  gem.add_development_dependency 'yard',          '>= 0.9.11'
end
