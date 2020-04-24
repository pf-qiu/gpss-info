#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 server_CN client_CN"
  exit 1
fi

# Define server and client CN variable
server_cn=$1
client_cn=$2
# Generate CSR for server1
openssl req -new -newkey rsa:2048 -nodes \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=${server_cn}" \
  -keyout server.key -out server.csr
 
# Sign server1 certificate by intermediate CA.
openssl x509 -req -in server.csr -CA interca.crt -CAkey interca.key \
  -days 365 -out server.crt -sha256 -CAcreateserial
 
# Generate CSR for client1
openssl req -new -newkey rsa:2048 -nodes \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=${client_cn}" \
  -keyout client.key -out client.csr
 
# Sign client1 certificate by intermediate CA.
openssl x509 -req -in client.csr -CA interca.crt -CAkey interca.key \
  -days 365 -out client.crt -sha256 -CAcreateserial
 
# Merge server certificate chain
cat interca.crt >> server.crt
cat root.crt >> server.crt
# Merge client certificate chain
cat interca.crt >> client.crt
cat root.crt >> client.crt
