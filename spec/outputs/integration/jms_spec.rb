require_relative '../spec_helper'
require 'logstash/outputs/jms'
require 'jms'
require 'json'

shared_examples_for "a JMS output" do
  context 'when outputting messages' do
    it 'should send logstash event to jms queue' do
      output.register

      output.receive(event)
      # Check the message is correct on the queue.
      # Create config file to pass to JMS Connection
      config = output.jms_config_from_yaml(fixture_path('jms.yml'), 'activemq')
      raise "JMS Provider option:#{jms_provider} not found in jms.yml file" unless config

      # Consume all available messages on the queue
      messages = []
      JMS::Connection.session(config) do |session|
        session.consume(:queue_name => 'ExampleQueue', :timeout => 1000) {|message| messages << message }
      end
      expect(messages.size).to eql 1
      expect(messages.first.data).to include "hello"
    end
  end

end

describe "outputs/jms", :integration => true do
  let (:jms_config) {{'yaml_file' => fixture_path("jms.yml"), 'yaml_section' => 'activemq', 'destination' => 'ExampleQueue'}}
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

  # context 'with tls', :tls => true do
  #   let (:jms_config) { super.merge({'yaml_section' => 'activemq_tls',
  #                                    "keystore" => fixture_path("keystore.jks"), "keystore_password" => "changeit",
  #                                    "truststore" => fixture_path("keystore.jks"), "truststore_password" => "changeit"})}
  # 
  #   it_behaves_like 'a JMS output'
  # end

end