#!/usr/bin/env ruby
# frozen_string_literal: true

require "mqtt"

proxy = MQTT::Proxy.new(
  local_host: "0.0.0.0",
  local_port: 1883,
  server_host: "test.mosquitto.org",
  server_port: 1883
)

proxy.client_filter = lambda { |packet|
  puts "From client: #{packet.inspect}"
  packet
}

proxy.server_filter = lambda { |packet|
  puts "From server: #{packet.inspect}"
  packet
}

# Start the proxy
proxy.run
