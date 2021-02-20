# encoding: BINARY
# frozen_string_literal: true

# Encoding is set to binary, so that the binary packets aren't validated as UTF-8

require 'spec_helper'

describe MQTT::SN::Packet do
  describe 'when creating a new packet' do
    it 'allows you to set the packet dup flag as a hash parameter' do
      packet = MQTT::SN::Packet.new(duplicate: true)
      expect(packet.duplicate).to be_truthy
    end

    it 'allows you to set the packet QoS level as a hash parameter' do
      packet = MQTT::SN::Packet.new(qos: 2)
      expect(packet.qos).to eq(2)
    end

    it 'allows you to set the packet retain flag as a hash parameter' do
      packet = MQTT::SN::Packet.new(retain: true)
      expect(packet.retain).to be_truthy
    end
  end

  describe 'getting the type id on a un-subclassed packet' do
    it 'raises an exception' do
      expect do
        MQTT::SN::Packet.new.type_id
      end.to raise_error(
        RuntimeError,
        'Invalid packet type: MQTT::SN::Packet'
      )
    end
  end

  describe 'Parsing a packet that does not match the packet length' do
    it 'raises an exception' do
      expect do
        MQTT::SN::Packet.parse("\x02\x1834567")
      end.to raise_error(
        MQTT::SN::ProtocolException,
        'Length of packet is not the same as the length header'
      )
    end
  end

  describe MQTT::SN::Packet::Advertise do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Advertise.new
      expect(packet.type_id).to eq(0x00)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Advertise.new(gateway_id: 5, duration: 30)
        expect(packet.to_s).to eq("\x05\x00\x05\x00\x1E")
      end
    end

    describe 'when parsing a ADVERTISE packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x05\x00\x05\x00\x3C") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Advertise)
      end

      it 'sets the gateway id of the packet correctly' do
        expect(packet.gateway_id).to eq(5)
      end

      it 'sets the duration of the packet correctly' do
        expect(packet.duration).to eq(60)
      end
    end
  end

  describe MQTT::SN::Packet::Searchgw do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Searchgw.new
      expect(packet.type_id).to eq(0x01)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Searchgw.new(radius: 2)
        expect(packet.to_s).to eq("\x03\x01\x02")
      end
    end

    describe 'when parsing a ADVERTISE packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x01\x03") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Searchgw)
      end

      it 'sets the duration of the packet correctly' do
        expect(packet.radius).to eq(3)
      end
    end
  end

  describe MQTT::SN::Packet::Gwinfo do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Gwinfo.new
      expect(packet.type_id).to eq(0x02)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes when there is no gateway address' do
        packet = MQTT::SN::Packet::Gwinfo.new(gateway_id: 6)
        expect(packet.to_s).to eq("\x03\x02\x06")
      end

      it 'outputs the correct bytes with a gateway address' do
        packet = MQTT::SN::Packet::Gwinfo.new(gateway_id: 6, gateway_address: 'ADDR')
        expect(packet.to_s).to eq("\x07\x02\x06ADDR")
      end
    end

    describe 'when parsing a GWINFO packet with no gateway address' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x02\x06") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Gwinfo)
      end

      it 'sets the Gateway ID of the packet correctly' do
        expect(packet.gateway_id).to eq(6)
      end

      it 'sets the Gateway ID of the packet correctly' do
        expect(packet.gateway_address).to be_nil
      end
    end

    describe 'when parsing a GWINFO packet with a gateway address' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x02\x06ADDR") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Gwinfo)
      end

      it 'sets the Gateway ID of the packet correctly' do
        expect(packet.gateway_id).to eq(6)
      end

      it 'sets the Gateway ID of the packet correctly' do
        expect(packet.gateway_address).to eq('ADDR')
      end
    end
  end

  describe MQTT::SN::Packet::Connect do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Connect.new
      expect(packet.type_id).to eq(0x04)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a packet with no flags' do
        packet = MQTT::SN::Packet::Connect.new(
          client_id: 'mqtt-sn-client-pub'
        )
        expect(packet.to_s).to eq("\x18\x04\x04\x01\x00\x0fmqtt-sn-client-pub")
      end

      it 'outputs the correct bytes for a packet with clean session turned off' do
        packet = MQTT::SN::Packet::Connect.new(
          client_id: 'myclient',
          clean_session: false
        )
        expect(packet.to_s).to eq("\016\004\000\001\000\017myclient")
      end

      it 'raises an exception when there is no client identifier' do
        expect do
          MQTT::SN::Packet::Connect.new.to_s
        end.to raise_error(
          'Invalid client identifier when serialising packet'
        )
      end

      it 'outputs the correct bytes for a packet with a will request' do
        packet = MQTT::SN::Packet::Connect.new(
          client_id: 'myclient',
          request_will: true,
          clean_session: true
        )
        expect(packet.to_s).to eq("\016\004\014\001\000\017myclient")
      end

      it 'outputs the correct bytes for with a custom keep alive' do
        packet = MQTT::SN::Packet::Connect.new(
          client_id: 'myclient',
          request_will: true,
          clean_session: true,
          keep_alive: 30
        )
        expect(packet.to_s).to eq("\016\004\014\001\000\036myclient")
      end
    end

    describe 'when parsing a simple Connect packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x18\x04\x04\x01\x00\x00mqtt-sn-client-pub") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Connect)
      end

      it 'does not have the request will flag set' do
        expect(packet.request_will).to be_falsy
      end

      it 'shoul have the clean session flag set' do
        expect(packet.clean_session).to be_truthy
      end

      it 'sets the Keep Alive timer of the packet correctly' do
        expect(packet.keep_alive).to eq(0)
      end

      it 'sets the Client Identifier of the packet correctly' do
        expect(packet.client_id).to eq('mqtt-sn-client-pub')
      end
    end

    describe 'when parsing a Connect packet with the clean session flag set' do
      let(:packet) { MQTT::SN::Packet.parse("\016\004\004\001\000\017myclient") }

      it 'sets the clean session flag' do
        expect(packet.clean_session).to be_truthy
      end
    end

    describe 'when parsing a Connect packet with the will request flag set' do
      let(:packet) { MQTT::SN::Packet.parse("\016\004\014\001\000\017myclient") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Connect)
      end

      it 'sets the Client Identifier of the packet correctly' do
        expect(packet.client_id).to eq('myclient')
      end

      it 'sets the clean session flag should be set' do
        expect(packet.clean_session).to be_truthy
      end

      it 'sets the Will retain flag should be false' do
        expect(packet.request_will).to be_truthy
      end
    end

    context 'that has an invalid type identifier' do
      it 'raises an exception' do
        expect do
          MQTT::SN::Packet.parse("\x02\xFF")
        end.to raise_error(
          MQTT::SN::ProtocolException,
          'Invalid packet type identifier: 255'
        )
      end
    end

    describe 'when parsing a Connect packet an unsupport protocol ID' do
      it 'raises an exception' do
        expect do
          MQTT::SN::Packet.parse(
            "\016\004\014\005\000\017myclient"
          )
        end.to raise_error(
          MQTT::SN::ProtocolException,
          'Unsupported protocol ID number: 5'
        )
      end
    end
  end

  describe MQTT::SN::Packet::Connack do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Connack.new
      expect(packet.type_id).to eq(0x05)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a sucessful connection acknowledgement packet' do
        packet = MQTT::SN::Packet::Connack.new(return_code: 0x00)
        expect(packet.to_s).to eq("\x03\x05\x00")
      end

      it "raises an exception if the return code isn't an Integer" do
        packet = MQTT::SN::Packet::Connack.new(return_code: true)
        expect { packet.to_s }.to raise_error('return_code must be an Integer')
      end
    end

    describe 'when parsing a successful Connection Accepted packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x00") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Connack)
      end

      it 'sets the return code of the packet correctly' do
        expect(packet.return_code).to eq(0x00)
      end

      it 'sets the return message of the packet correctly' do
        expect(packet.return_msg).to match(/accepted/i)
      end
    end

    describe 'when parsing a congestion packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x01") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Connack)
      end

      it 'sets the return code of the packet correctly' do
        expect(packet.return_code).to eq(0x01)
      end

      it 'sets the return message of the packet correctly' do
        expect(packet.return_msg).to match(/rejected: congestion/i)
      end
    end

    describe 'when parsing a invalid topic ID packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x02") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Connack)
      end

      it 'sets the return code of the packet correctly' do
        expect(packet.return_code).to eq(0x02)
      end

      it 'sets the return message of the packet correctly' do
        expect(packet.return_msg).to match(/rejected: invalid topic ID/i)
      end
    end

    describe "when parsing a 'not supported' packet" do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x03") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Connack)
      end

      it 'sets the return code of the packet correctly' do
        expect(packet.return_code).to eq(0x03)
      end

      it 'sets the return message of the packet correctly' do
        expect(packet.return_msg).to match(/not supported/i)
      end
    end

    describe 'when parsing an unknown connection refused packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x10") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Connack)
      end

      it 'sets the return code of the packet correctly' do
        expect(packet.return_code).to eq(0x10)
      end

      it 'sets the return message of the packet correctly' do
        expect(packet.return_msg).to match(/rejected/i)
      end
    end
  end

  describe MQTT::SN::Packet::Willtopicreq do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Willtopicreq.new
      expect(packet.type_id).to eq(0x06)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Willtopicreq.new
        expect(packet.to_s).to eq("\x02\x06")
      end
    end

    describe 'when parsing a Willtopicreq packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x02\x06") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willtopicreq)
      end
    end
  end

  describe MQTT::SN::Packet::Willtopic do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Willtopic.new
      expect(packet.type_id).to eq(0x07)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a Willtopic packet' do
        packet = MQTT::SN::Packet::Willtopic.new(topic_name: 'test', qos: 0)
        expect(packet.to_s).to eq("\x07\x07\x00test")
      end

      it 'outputs the correct bytes for a Willtopic packet with QoS 1' do
        packet = MQTT::SN::Packet::Willtopic.new(topic_name: 'test', qos: 1)
        expect(packet.to_s).to eq("\x07\x07\x20test")
      end

      it 'outputs the correct bytes for a Willtopic packet with no topic name' do
        packet = MQTT::SN::Packet::Willtopic.new(topic_name: nil)
        expect(packet.to_s).to eq("\x02\x07")
      end

      it 'outputs the correct bytes for a Willtopic packet with an empty topic name' do
        packet = MQTT::SN::Packet::Willtopic.new(topic_name: '')
        expect(packet.to_s).to eq("\x02\x07")
      end
    end

    describe 'when parsing a Willtopic packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x07\x40test") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willtopic)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to eq('test')
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(2)
      end

      it 'sets the retain flag of the packet correctly' do
        expect(packet.retain).to be_falsy
      end
    end

    describe 'when parsing a Willtopic packet with no topic name' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x07\x00") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willtopic)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to be_nil
      end
    end
  end

  describe MQTT::SN::Packet::Willmsgreq do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Willmsgreq.new
      expect(packet.type_id).to eq(0x08)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Willmsgreq.new
        expect(packet.to_s).to eq("\x02\x08")
      end
    end

    describe 'when parsing a Willmsgreq packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x02\x08") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willmsgreq)
      end
    end
  end

  describe MQTT::SN::Packet::Willmsg do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Willmsg.new
      expect(packet.type_id).to eq(0x09)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a Willmsg packet' do
        packet = MQTT::SN::Packet::Willmsg.new(data: 'msg')
        expect(packet.to_s).to eq("\x05\x09msg")
      end
    end

    describe 'when parsing a Willmsg packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x0D\x09willmessage") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willmsg)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.data).to eq('willmessage')
      end
    end
  end

  describe MQTT::SN::Packet::Register do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Register.new
      expect(packet.type_id).to eq(0x0A)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Register.new(
          id: 0x01,
          topic_id: 0x01,
          topic_name: 'test'
        )
        expect(packet.to_s).to eq("\x0A\x0A\x00\x01\x00\x01test")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Register.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end

      it "raises an exception if the Topic Id isn't an Integer" do
        packet = MQTT::SN::Packet::Register.new(topic_id: '0x45')
        expect { packet.to_s }.to raise_error('topic_id must be an Integer')
      end
    end

    describe 'when parsing a Register packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x0A\x0A\x00\x01\x00\x01test") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Register)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq(:normal)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq(0x01)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x01)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to eq('test')
      end
    end
  end

  describe MQTT::SN::Packet::Regack do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Regack.new
      expect(packet.type_id).to eq(0x0B)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Regack.new(
          id: 0x02,
          topic_id: 0x01,
          return_code: 0x03
        )
        expect(packet.to_s).to eq("\x07\x0B\x00\x01\x00\x02\x03")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Regack.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end

      it "raises an exception if the Topic Id isn't an Integer" do
        packet = MQTT::SN::Packet::Regack.new(topic_id: '0x45')
        expect { packet.to_s }.to raise_error('topic_id must be an Integer')
      end
    end

    describe 'when parsing a REGACK packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x0B\x00\x01\x00\x02\x03") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Regack)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq(:normal)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq(0x01)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x02)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.return_code).to eq(0x03)
      end
    end
  end

  describe MQTT::SN::Packet::Publish do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Publish.new
      expect(packet.type_id).to eq(0x0C)
    end

    describe 'when serialising a packet with a normal topic id type' do
      it 'outputs the correct bytes for a publish packet' do
        packet = MQTT::SN::Packet::Publish.new(
          topic_id: 0x01,
          topic_id_type: :normal,
          data: 'Hello World'
        )
        expect(packet.to_s).to eq("\x12\x0C\x00\x00\x01\x00\x00Hello World")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Publish.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end
    end

    describe 'when serialising a packet with a short topic id type' do
      it 'outputs the correct bytes for a publish packet of QoS -1' do
        packet = MQTT::SN::Packet::Publish.new(
          qos: -1,
          topic_id: 'tt',
          topic_id_type: :short,
          data: 'Hello World'
        )
        expect(packet.to_s).to eq("\x12\x0C\x62tt\x00\x00Hello World")
      end

      it 'outputs the correct bytes for a publish packet of QoS 0' do
        packet = MQTT::SN::Packet::Publish.new(
          qos: 0,
          topic_id: 'tt',
          topic_id_type: :short,
          data: 'Hello World'
        )
        expect(packet.to_s).to eq("\x12\x0C\x02tt\x00\x00Hello World")
      end

      it 'outputs the correct bytes for a publish packet of QoS 1' do
        packet = MQTT::SN::Packet::Publish.new(
          qos: 1,
          topic_id: 'tt',
          topic_id_type: :short,
          data: 'Hello World'
        )
        expect(packet.to_s).to eq("\x12\x0C\x22tt\x00\x00Hello World")
      end

      it 'outputs the correct bytes for a publish packet of QoS 2' do
        packet = MQTT::SN::Packet::Publish.new(
          qos: 2,
          topic_id: 'tt',
          topic_id_type: :short,
          data: 'Hello World'
        )
        expect(packet.to_s).to eq("\x12\x0C\x42tt\x00\x00Hello World")
      end
    end

    describe 'when serialising a packet with a pre-defined topic id type' do
      it 'outputs the correct bytes for a publish packet' do
        packet = MQTT::SN::Packet::Publish.new(
          topic_id: 0x00EE,
          topic_id_type: :predefined,
          data: 'Hello World'
        )
        expect(packet.to_s).to eq("\x12\x0C\x01\x00\xEE\x00\x00Hello World")
      end
    end

    describe 'when serialising packet larger than 256 bytes' do
      let(:packet) do
        MQTT::SN::Packet::Publish.new(
          topic_id: 0x10,
          topic_id_type: :normal,
          data: 'Hello World' * 100
        )
      end

      it 'has the first three bytes set to 0x01, 0x04, 0x55' do
        expect(packet.to_s.unpack('CCC')).to eq([0x01, 0x04, 0x55])
      end

      it 'has a total length of 0x0455 (1109) bytes' do
        expect(packet.to_s.length).to eq(0x0455)
      end
    end

    describe 'when serialising an excessively large packet' do
      it 'raises an exception' do
        expect do
          MQTT::SN::Packet::Publish.new(
            topic_id: 0x01,
            topic_id_type: :normal,
            data: 'Hello World' * 6553
          ).to_s
        end.to raise_error(
          RuntimeError,
          'MQTT-SN Packet is too big, maximum packet body size is 65531'
        )
      end
    end

    describe 'when parsing a Publish packet with a normal topic id' do
      let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x00\x00\x01\x00\x00Hello World") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Publish)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq 0
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq false
      end

      it 'sets the retain flag of the packet correctly' do
        expect(packet.retain).to eq false
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id_type).to eq :normal
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq 0x01
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq 0x0000
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.data).to eq('Hello World')
      end
    end

    describe 'when parsing a Publish packet with a short topic id' do
      let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x02tt\x00\x00Hello World") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Publish)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq 0
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq false
      end

      it 'sets the retain flag of the packet correctly' do
        expect(packet.retain).to eq false
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq :short
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq 'tt'
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq 0x0000
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.data).to eq('Hello World')
      end
    end

    describe 'when parsing a Publish packet with a short topic id and QoS -1' do
      let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x62tt\x00\x00Hello World") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Publish)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(-1)
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq false
      end

      it 'sets the retain flag of the packet correctly' do
        expect(packet.retain).to eq false
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq :short
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq 'tt'
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq 0x0000
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.data).to eq('Hello World')
      end
    end

    describe 'when parsing a Publish packet with a predefined topic id type' do
      let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x01\x00\xEE\x00\x00Hello World") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Publish)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to be(:predefined)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq(0xEE)
      end
    end

    describe 'when parsing a Publish packet with a invalid topic id type' do
      let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x03\x00\x10\x55\xCCHello World") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Publish)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq 0
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq false
      end

      it 'sets the retain flag of the packet correctly' do
        expect(packet.retain).to eq false
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to be_nil
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq(0x10)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq 0x55CC
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.data).to eq('Hello World')
      end
    end

    describe 'when parsing a Publish packet longer than 256 bytes' do
      let(:packet) { MQTT::SN::Packet.parse("\x01\x04\x55\x0C\x62tt\x00\x00" + ('Hello World' * 100)) }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Publish)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(-1)
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq false
      end

      it 'sets the retain flag of the packet correctly' do
        expect(packet.retain).to eq false
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq :short
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq 'tt'
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq 0x0000
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.data).to eq('Hello World' * 100)
      end
    end
  end

  describe MQTT::SN::Packet::Puback do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Puback.new
      expect(packet.type_id).to eq(0x0D)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Puback.new(id: 0x02, topic_id: 0x03, return_code: 0x01)
        expect(packet.to_s).to eq("\x07\x0D\x00\x03\x00\x02\x01")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Puback.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end

      it "raises an exception if the Topic Id isn't an Integer" do
        packet = MQTT::SN::Packet::Puback.new(topic_id: '0x45')
        expect { packet.to_s }.to raise_error('topic_id must be an Integer')
      end
    end

    describe 'when parsing a PUBACK packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x0D\x00\x01\x00\x02\x03") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Puback)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq(0x01)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x02)
      end

      it 'sets the return code of the packet correctly' do
        expect(packet.return_code).to eq(0x03)
      end
    end
  end

  describe MQTT::SN::Packet::Pubcomp do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Pubcomp.new
      expect(packet.type_id).to eq(0x0E)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Pubcomp.new(id: 0x02)
        expect(packet.to_s).to eq("\x04\x0E\x00\x02")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Pubcomp.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end
    end

    describe 'when parsing a PUBCOMP packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x04\x0E\x00\x02") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Pubcomp)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x02)
      end
    end
  end

  describe MQTT::SN::Packet::Pubrec do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Pubrec.new
      expect(packet.type_id).to eq(0x0F)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Pubrec.new(id: 0x02)
        expect(packet.to_s).to eq("\x04\x0F\x00\x02")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Pubrec.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end
    end

    describe 'when parsing a PUBREC packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x04\x0F\x00\x02") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Pubrec)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x02)
      end
    end
  end

  describe MQTT::SN::Packet::Pubrel do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Pubrel.new
      expect(packet.type_id).to eq(0x10)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Pubrel.new(id: 0x02)
        expect(packet.to_s).to eq("\x04\x10\x00\x02")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Pubrel.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end
    end

    describe 'when parsing a PUBREL packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x04\x10\x00\x02") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Pubrel)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x02)
      end
    end
  end

  describe MQTT::SN::Packet::Subscribe do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Subscribe.new
      expect(packet.type_id).to eq(0x12)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a Subscribe packet with a normal topic name' do
        packet = MQTT::SN::Packet::Subscribe.new(
          duplicate: false,
          qos: 0,
          id: 0x02,
          topic_name: 'test'
        )
        expect(packet.to_s).to eq("\x09\x12\x00\x00\x02test")
      end

      it 'outputs the correct bytes for a Subscribe packet with a short topic name' do
        packet = MQTT::SN::Packet::Subscribe.new(
          duplicate: false,
          qos: 0,
          id: 0x04,
          topic_id_type: :short,
          topic_name: 'TT'
        )
        expect(packet.to_s).to eq("\x07\x12\x02\x00\x04TT")
      end

      it 'outputs the correct bytes for a Subscribe packet with a short topic id' do
        packet = MQTT::SN::Packet::Subscribe.new(
          duplicate: false,
          qos: 0,
          id: 0x04,
          topic_id_type: :short,
          topic_id: 'TT'
        )
        expect(packet.to_s).to eq("\x07\x12\x02\x00\x04TT")
      end

      it 'outputs the correct bytes for a Subscribe packet with a predefined topic id' do
        packet = MQTT::SN::Packet::Subscribe.new(
          duplicate: false,
          qos: 0,
          id: 0x05,
          topic_id_type: :predefined,
          topic_id: 16
        )
        expect(packet.to_s).to eq("\x07\x12\x01\x00\x05\x00\x10")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Subscribe.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end
    end

    describe 'when parsing a Subscribe packet with a normal topic id type' do
      let(:packet) { MQTT::SN::Packet.parse("\x09\x12\x00\x00\x03test") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Subscribe)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x03)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(0)
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq(false)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq(:normal)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to eq('test')
      end
    end

    describe 'when parsing a Subscribe packet with a short topic id type' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x12\x02\x00\x04TT") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Subscribe)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x04)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(0)
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq(false)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq(:short)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq('TT')
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to eq('TT')
      end
    end

    describe 'when parsing a Subscribe packet with a predefined topic id type' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x12\x01\x00\x05\x00\x10") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Subscribe)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x05)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(0)
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq(false)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq(:predefined)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq(16)
      end

      it 'sets the topic name of the packet to nil' do
        expect(packet.topic_name).to be_nil
      end
    end
  end

  describe MQTT::SN::Packet::Suback do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Suback.new
      expect(packet.type_id).to eq(0x13)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a normal topic id' do
        packet = MQTT::SN::Packet::Suback.new(
          id: 0x02,
          qos: 0,
          topic_id: 0x01,
          return_code: 0x03
        )
        expect(packet.to_s).to eq("\x08\x13\x00\x00\x01\x00\x02\x03")
      end

      it 'outputs the correct bytes for a short topic id' do
        packet = MQTT::SN::Packet::Suback.new(
          id: 0x03,
          qos: 0,
          topic_id: 'tt',
          topic_id_type: :short,
          return_code: 0x03
        )
        expect(packet.to_s).to eq("\x08\x13\x02tt\x00\x03\x03")
      end

      it 'outputs the correct bytes for a packet with no topic id' do
        packet = MQTT::SN::Packet::Suback.new(
          id: 0x02,
          return_code: 0x02
        )
        expect(packet.to_s).to eq("\x08\x13\x00\x00\x00\x00\x02\x02")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Suback.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end

      it "raises an exception if the Topic Id isn't an Integer" do
        packet = MQTT::SN::Packet::Suback.new(topic_id: '0x45', topic_id_type: :normal)
        expect { packet.to_s }.to raise_error('topic_id must be an Integer for type normal')
      end

      it "raises an exception if the Topic Id isn't a String" do
        packet = MQTT::SN::Packet::Suback.new(topic_id: 10, topic_id_type: :short)
        expect { packet.to_s }.to raise_error('topic_id must be an String for type short')
      end
    end

    describe 'when parsing a SUBACK packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x08\x13\x00\x00\x01\x00\x02\x03") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Suback)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.qos).to eq(0)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq(:normal)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq(0x01)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x02)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.return_code).to eq(0x03)
      end
    end
  end

  describe MQTT::SN::Packet::Unsubscribe do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Unsubscribe.new
      expect(packet.type_id).to eq(0x14)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a Unsubscribe packet with a normal topic name' do
        packet = MQTT::SN::Packet::Unsubscribe.new(
          id: 0x02,
          duplicate: false,
          qos: 0,
          topic_name: 'test'
        )
        expect(packet.to_s).to eq("\x09\x14\x00\x00\x02test")
      end

      it 'outputs the correct bytes for a Unsubscribe packet with a short topic name' do
        packet = MQTT::SN::Packet::Unsubscribe.new(
          duplicate: false,
          qos: 0,
          id: 0x04,
          topic_id_type: :short,
          topic_name: 'TT'
        )
        expect(packet.to_s).to eq("\x07\x14\x02\x00\x04TT")
      end

      it 'outputs the correct bytes for a Unsubscribe packet with a short topic id' do
        packet = MQTT::SN::Packet::Unsubscribe.new(
          duplicate: false,
          qos: 0,
          id: 0x04,
          topic_id_type: :short,
          topic_id: 'TT'
        )
        expect(packet.to_s).to eq("\x07\x14\x02\x00\x04TT")
      end

      it 'outputs the correct bytes for a Unsubscribe packet with a predefined topic id' do
        packet = MQTT::SN::Packet::Unsubscribe.new(
          duplicate: false,
          qos: 0,
          id: 0x05,
          topic_id_type: :predefined,
          topic_id: 16
        )
        expect(packet.to_s).to eq("\x07\x14\x01\x00\x05\x00\x10")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Unsubscribe.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end
    end

    describe 'when parsing a Unsubscribe packet with a normal topic id type' do
      let(:packet) { MQTT::SN::Packet.parse("\x09\x14\x00\x00\x03test") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Unsubscribe)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x03)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(0)
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq(false)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to eq('test')
      end
    end

    describe 'when parsing a Subscribe packet with a short topic id type' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x14\x02\x00\x04TT") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Unsubscribe)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x04)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(0)
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq(false)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq(:short)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq('TT')
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to eq('TT')
      end
    end

    describe 'when parsing a Subscribe packet with a predefined topic id type' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x14\x01\x00\x05\x00\x10") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Unsubscribe)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x05)
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(0)
      end

      it 'sets the duplicate flag of the packet correctly' do
        expect(packet.duplicate).to eq(false)
      end

      it 'sets the topic id type of the packet correctly' do
        expect(packet.topic_id_type).to eq(:predefined)
      end

      it 'sets the topic id of the packet correctly' do
        expect(packet.topic_id).to eq(16)
      end

      it 'sets the topic name of the packet to nil' do
        expect(packet.topic_name).to be_nil
      end
    end
  end

  describe MQTT::SN::Packet::Unsuback do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Unsuback.new
      expect(packet.type_id).to eq(0x15)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Unsuback.new(id: 0x02)
        expect(packet.to_s).to eq("\x04\x15\x00\x02")
      end

      it "raises an exception if the Packet Id isn't an Integer" do
        packet = MQTT::SN::Packet::Unsuback.new(id: '0x45')
        expect { packet.to_s }.to raise_error('id must be an Integer')
      end
    end

    describe 'when parsing a SUBACK packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x04\x15\x00\x02") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Unsuback)
      end

      it 'sets the message id of the packet correctly' do
        expect(packet.id).to eq(0x02)
      end
    end
  end

  describe MQTT::SN::Packet::Pingreq do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Pingreq.new
      expect(packet.type_id).to eq(0x16)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a pingreq packet' do
        packet = MQTT::SN::Packet::Pingreq.new
        expect(packet.to_s).to eq("\x02\x16")
      end
    end

    describe 'when parsing a Pingreq packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x02\x16") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Pingreq)
      end
    end
  end

  describe MQTT::SN::Packet::Pingresp do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Pingresp.new
      expect(packet.type_id).to eq(0x17)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a pingresp packet' do
        packet = MQTT::SN::Packet::Pingresp.new
        expect(packet.to_s).to eq("\x02\x17")
      end
    end

    describe 'when parsing a Pingresp packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x02\x17") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Pingresp)
      end
    end
  end

  describe MQTT::SN::Packet::Disconnect do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Disconnect.new
      expect(packet.type_id).to eq(0x18)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a disconnect packet' do
        packet = MQTT::SN::Packet::Disconnect.new
        expect(packet.to_s).to eq("\x02\x18")
      end

      it 'outputs the correct bytes for a disconnect packet with a duration' do
        packet = MQTT::SN::Packet::Disconnect.new(duration: 10)
        expect(packet.to_s).to eq("\x04\x18\x00\x0A")
      end
    end

    describe 'when parsing a Disconnect packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x02\x18") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Disconnect)
      end

      it 'has the duration field set to nil' do
        expect(packet.duration).to be_nil
      end
    end

    describe 'when parsing a Disconnect packet with duration field' do
      let(:packet) { MQTT::SN::Packet.parse("\x04\x18\x00\x0A") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Disconnect)
      end

      it 'has the duration field set to 10' do
        expect(packet.duration).to eq(10)
      end
    end
  end

  describe MQTT::SN::Packet::Willtopicupd do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Willtopicupd.new
      expect(packet.type_id).to eq(0x1A)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a Willtopicupd packet' do
        packet = MQTT::SN::Packet::Willtopicupd.new(topic_name: 'test', qos: 0)
        expect(packet.to_s).to eq("\x07\x1A\x00test")
      end

      it 'outputs the correct bytes for a Willtopic packet with QoS 1' do
        packet = MQTT::SN::Packet::Willtopicupd.new(topic_name: 'test', qos: 1)
        expect(packet.to_s).to eq("\x07\x1A\x20test")
      end

      it 'outputs the correct bytes for a Willtopic packet with no topic name' do
        packet = MQTT::SN::Packet::Willtopicupd.new(topic_name: nil)
        expect(packet.to_s).to eq("\x02\x1A")
      end

      it 'outputs the correct bytes for a Willtopic packet with an empty topic name' do
        packet = MQTT::SN::Packet::Willtopicupd.new(topic_name: '')
        expect(packet.to_s).to eq("\x02\x1A")
      end
    end

    describe 'when parsing a Willtopicupd packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x1A\x40test") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willtopicupd)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to eq('test')
      end

      it 'sets the QoS value of the packet correctly' do
        expect(packet.qos).to eq(2)
      end

      it 'sets the retain flag of the packet correctly' do
        expect(packet.retain).to be_falsy
      end
    end

    describe 'when parsing a Willtopicupd packet with no topic name' do
      let(:packet) { MQTT::SN::Packet.parse("\x02\x1A") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willtopicupd)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.topic_name).to be_nil
      end
    end
  end

  describe MQTT::SN::Packet::Willtopicresp do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Willtopicresp.new
      expect(packet.type_id).to eq(0x1B)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Willtopicresp.new(
          return_code: 0x03
        )
        expect(packet.to_s).to eq("\x03\x1B\x03")
      end

      it "raises an exception if the return code isn't an Integer" do
        packet = MQTT::SN::Packet::Willtopicresp.new(return_code: true)
        expect { packet.to_s }.to raise_error('return_code must be an Integer')
      end
    end

    describe 'when parsing a WILLTOPICRESP packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x1B\x04") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willtopicresp)
      end

      it 'sets the return code of the packet correctly' do
        expect(packet.return_code).to eq(0x04)
      end
    end
  end

  describe MQTT::SN::Packet::Willmsgupd do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Willmsgupd.new
      expect(packet.type_id).to eq(0x1C)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes for a Willmsgupd packet' do
        packet = MQTT::SN::Packet::Willmsgupd.new(data: 'test1')
        expect(packet.to_s).to eq("\x07\x1Ctest1")
      end
    end

    describe 'when parsing a Willmsgupd packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x07\x1Ctest2") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willmsgupd)
      end

      it 'sets the topic name of the packet correctly' do
        expect(packet.data).to eq('test2')
      end
    end
  end

  describe MQTT::SN::Packet::Willmsgresp do
    it 'has the right type id' do
      packet = MQTT::SN::Packet::Willmsgresp.new
      expect(packet.type_id).to eq(0x1D)
    end

    describe 'when serialising a packet' do
      it 'outputs the correct bytes' do
        packet = MQTT::SN::Packet::Willmsgresp.new(
          return_code: 0x03
        )
        expect(packet.to_s).to eq("\x03\x1D\x03")
      end

      it "raises an exception if the return code isn't an Integer" do
        packet = MQTT::SN::Packet::Willmsgresp.new(return_code: true)
        expect { packet.to_s }.to raise_error('return_code must be an Integer')
      end
    end

    describe 'when parsing a WILLMSGRESP packet' do
      let(:packet) { MQTT::SN::Packet.parse("\x03\x1D\x04") }

      it 'correctlies create the right type of packet object' do
        expect(packet.class).to eq(MQTT::SN::Packet::Willmsgresp)
      end

      it 'sets the return code of the packet correctly' do
        expect(packet.return_code).to eq(0x04)
      end
    end
  end
end
