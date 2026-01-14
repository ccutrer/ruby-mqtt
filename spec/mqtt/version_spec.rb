# frozen_string_literal: true

require "spec_helper"
require "mqtt"

describe MQTT::VERSION do
  describe "version number" do
    it "is defined as a constant" do
      expect(defined?(MQTT::VERSION)).to eq("constant")
    end

    it "is a string" do
      expect(MQTT::VERSION).to be_a(String)
    end

    it "is in the format x.y.z" do
      expect(MQTT::VERSION).to match(/^\d{1,2}\.\d{1,2}\.\d{1,2}$/)
    end
  end
end
