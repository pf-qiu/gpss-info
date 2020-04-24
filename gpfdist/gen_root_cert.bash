#!/bin/bash

# Generate root certificate authority.
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=rootca" \
  -keyout root.key  -out root.crt
 
# Generate CSR for intermediate CA
openssl req -new -newkey rsa:2048 -nodes \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=interca" \
  -keyout interca.key -out interca.csr
# Sign intermediate CA by Root CA.
openssl x509 -req -in interca.csr -CA root.crt -CAkey root.key \
  -extfile <(printf "basicConstraints=CA:TRUE") \
  -days 365 -out interca.crt -sha256 -CAcreateserial