#!/bin/bash
set -e

if [ -n "${ACTIVEMQ_VERSION+1}" ]; then
  echo "ACTIVEMQ_VERSION is $ACTIVEMQ_VERSION"
else
   ACTIVEMQ_VERSION=5.15.8
fi

apache-activemq-$ACTIVEMQ_VERSION/bin/activemq stop
rm ./spec/outputs/fixtures/activemq-all.jar
rm -rf apache-activemq-$ACTIVEMQ_VERSION
rm activemq-bin.tar.gz