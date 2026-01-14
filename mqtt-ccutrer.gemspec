# frozen_string_literal: true

require_relative "lib/mqtt/version"

Gem::Specification.new do |gem|
  gem.name          = "mqtt-ccutrer"
  gem.version       = MQTT::VERSION
  gem.author        = "Cody Cutrer"
  gem.email         = "cody@cutrer.us"
  gem.homepage      = "http://github.com/ccutrer/ruby-mqtt"
  gem.summary       = "Implementation of the MQTT protocol"
  gem.description   = <<~TEXT
    Pure Ruby gem that implements the MQTT protocol, a lightweight protocol for
    publish/subscribe messaging.
  TEXT
  gem.license       = "MIT"
  gem.files         = %w[README.md LICENSE.md NEWS.md] + Dir.glob("lib/**/*.rb")
  gem.require_paths = %w[lib]
  gem.metadata["rubygems_mfa_required"] = "true"

  gem.required_ruby_version = ">= 3.1"

  gem.add_dependency "logger", "~> 1.7"
end
