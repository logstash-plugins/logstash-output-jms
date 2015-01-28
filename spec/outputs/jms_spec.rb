require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/jms'
require 'jms'
require 'json'

def getYamlPath()
  return File.join(File.dirname(__FILE__),"jms.yml")
end

describe "outputs/jms" do
  let (:jms_config) {{'yaml_file' => getYamlPath(), 'yaml_section' => 'hornetq', 'destination' => 'ExampleQueue'}}
  let (:event) { LogStash::Event.new({'message' => 'hello',
                                      '@timestamp' => LogStash::Timestamp.now}) }

  context 'when initializing' do
    it "should register" do
      output = LogStash::Plugin.lookup("output", "jms").new(jms_config)
      expect {output.register}.to_not raise_error
    end

    it 'should populate jms config with default values' do
      jms = LogStash::Outputs::Jms.new(jms_config)
      insist {jms.pub_sub} == false
    end
  end

  context 'when outputting messages' do
    it 'should send logstash event to jms queue' do
      jms = LogStash::Outputs::Jms.new(jms_config)
      jms.register
      jms.receive(event)
    end
  end
end