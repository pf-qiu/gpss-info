#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 root_CN intermediate_CN server_CN client_CN"
  exit 1
fi

# Define CN variable
root_cn=rootca1
inter_cn=interca1
server_cn=server1
client_cn=client1
 
# Generate root certificate authority.
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=${root_cn}" \
  -keyout root.key  -out root.crt
 
# Generate CSR for intermediate CA
openssl req -new -newkey rsa:2048 -nodes \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=${inter_cn}" \
  -keyout interca.key -out interca.csr
# Sign intermediate CA by Root CA.
openssl x509 -req -in interca.csr -CA root.crt -CAkey root.key \
  -extfile <(printf "basicConstraints=CA:TRUE") \
  -days 365 -out interca.crt -sha256 -CAcreateserial
 
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