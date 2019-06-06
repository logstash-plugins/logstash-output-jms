# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"

def fixture_path(file)
  File.join(File.dirname(__FILE__),"fixtures/#{file}")
end

def retrieve_messages_from_queue
  config = output.jms_config_from_yaml(fixture_path('jms.yml'), 'activemq')
  raise "JMS Provider option:#{jms_provider} not found in jms.yml file" unless config

  # Consume all available messages on the queue
  messages = []
  JMS::Connection.session(config) do |session|
    session.consume(:queue_name => 'ExampleQueue', :timeout => 1000) {|message| messages << message}
  end
  messages
end
