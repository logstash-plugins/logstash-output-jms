require_relative '../spec_helper'
require 'logstash/outputs/jms'
require 'jms'
require 'json'


shared_examples_for "a JMS output" do
  context 'when outputting messages' do
    let(:messages) { retrieve_messages_from_queue(yaml_section) }
    before :each do
      output.register
      output.receive(event)
    end

    it 'should send logstash event to jms queue' do
      # Check the message is correct on the queue.
      # Create config file to pass to JMS Connection
      expect(messages.size).to eql 1
      expect(messages.first.data).to include "hello"
    end

    context 'should set set delivery mode correctly' do
      %w(persistent non_persistent).each do |delivery_mode|
        context "when the delivery mode is #{delivery_mode}" do
          let(:jms_config) { super.merge('delivery_mode' => delivery_mode) }
          it "should set the delivery mode to #{delivery_mode}" do
            # Check the message is correct on the queue.
            # Create config file to pass to JMS Connection
            expect(messages.size).to eql 1
            expect(messages.first.jms_delivery_mode_sym).to eql(delivery_mode.to_sym)
          end
        end
      end
    end

    context 'Time to live is not set' do
      it "jms_expiration should be 0" do
        # Check the message is correct on the queue.
        # Create config file to pass to JMS Connection
        expect(messages.size).to eql 1
        expect(messages.first.jms_expiration).to eql(0)
      end
    end

    context 'Time to live is set' do
      let(:jms_config) { super.merge('time_to_live' => 20000) }

      it "jms_expiration should be jms_timestamp + ttl" do
        # Check the message is correct on the queue.
        # Create config file to pass to JMS Connection
        expect(messages.size).to eql 1
        expect(messages.first.jms_expiration).to eql(messages.first.jms_timestamp + 20000)
      end
    end


    context 'Priority is set' do
      let(:jms_config) { super.merge('priority' => 8) }

      it "jms_priority header should be set" do
        # Check the message is correct on the queue.
        # Create config file to pass to JMS Connection
        expect(messages.size).to eql 1
        expect(messages.first.jms_priority).to eql(8)
      end
    end

  end
end


describe "outputs/jms", :integration => true do
  let (:yaml_section) { 'activemq' }
  let (:jms_config) {{'yaml_file' => fixture_path("jms.yml"), 'yaml_section' => yaml_section, 'destination' => 'ExampleQueue'}}
  let (:event) { LogStash::Event.new({'message' => 'hello',
                                      '@timestamp' => LogStash::Timestamp.now}) }
  let(:output) { LogStash::Plugin.lookup("output", "jms").new(jms_config) }

  before :each do
    allow(output).to receive(:jms_config_from_yaml) do |yaml_file, section|
      settings = YAML.load_file(yaml_file)[section]
      settings[:require_jars] = [fixture_path("activemq-all.jar")]
      settings
    end
  end

  after :each do
    output.close unless output.nil?
  end

  context 'with plaintext', :plaintext => true do
    it_behaves_like 'a JMS output'
  end

  context 'with tls', :tls => true do
    let (:yaml_section) { 'activemq_tls' }
    let (:jms_config) { super.merge({"keystore" => fixture_path("keystore.jks"), "keystore_password" => "changeit",
                                     "truststore" => fixture_path("keystore.jks"), "truststore_password" => "changeit"})}

    it_behaves_like 'a JMS output'
  end

end