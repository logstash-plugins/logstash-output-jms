# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"

def yaml_path(file='jms.yml')
  File.join(File.dirname(__FILE__),"fixtures/#{file}")
end
