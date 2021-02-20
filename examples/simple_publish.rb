#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Connect to a MQTT server, send message and disconnect again.
#

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'rubygems'
require 'mqtt'

MQTT::Client.connect('test.mosquitto.org') do |client|
  client.publish('test', "The time is: #{Time.now}")
end
