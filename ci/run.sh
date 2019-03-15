#!/bin/bash
export ACTIVEMQ_VERSION=5.15.8
./setup_broker.sh
bundle install
bundle exec rspec && bundle exec rspec --tag integration
./teardown_broker.sh