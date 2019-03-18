#!/bin/bash
set -e
scp ./spec/outputs/fixtures/activemq_plaintext.xml activemq/conf/activemq.xml
activemq/bin/activemq start
