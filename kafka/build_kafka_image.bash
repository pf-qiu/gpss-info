#!/bin/bash
if [ ! -f confluent-oss-5.0.0-2.11.tar.gz ]; then
curl http://packages.confluent.io/archive/5.0/confluent-oss-5.0.0-2.11.tar.gz -o confluent-oss-5.0.0-2.11.tar.gz
fi
docker build . -t kafka
