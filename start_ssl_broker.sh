#!/bin/bash
set -e
scp ./spec/outputs/fixtures/activemq_ssl.xml activemq/conf/activemq.xml
activemq/bin/activemq start
