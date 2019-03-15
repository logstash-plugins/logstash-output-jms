require_relative '../spec_helper'
require 'logstash/outputs/jms'
require 'jms'
require 'json'

describe "outputs/jms", :integration => true do
  let (:jms_config) {{'yaml_file' => yaml_path, 'yaml_section' => 'activemq', 'destination' => 'ExampleQueue'}}
  let (:event) { LogStash::Event.new({'message' => 'hello',
                                      '@timestamp' => LogStash::Timestamp.now}) }
  let(:output) { LogStash::Plugin.lookup("output", "jms").new(jms_config) }

  before :each do
    allow(output).to receive(:jms_config_from_yaml) do |yaml_file, section|
      settings = YAML.load_file(yaml_file)[section]
      settings[:require_jars] = [File.join(File.dirname(__FILE__),"../fixtures/activemq-all.jar")]
      settings
    end
  end

  after :each do
    output.close unless output.nil?
  end

  context 'when outputting messages' do
    it 'should send logstash event to jms queue' do
      output.register
      output.receive(event)

      # Add code to check the message is correct on the queue.
      config = output.jms_config_from_yaml(yaml_path, 'activemq')
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