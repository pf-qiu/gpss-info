#!/bin/bash

if [ -z "${endpoints}" ]; then
echo "Please specify endpoints environment variable, like:"
echo 'export endpoints="kafka0 kafka1 etl"'
exit 1
fi

if [ -z "${storepass}" ]; then
echo "Please specify storepass environment variable, like:"
echo "export storepass=123456"
exit 1
fi

# Generate root certificate authority.
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=rootca" \
  -keyout ca.key  -out ca.crt

yes | keytool -keystore trust.jks -alias ca -importcert -file ca.crt -storepass ${storepass}

# Generate intermediate CA and cert for each endpoint(kafka broker, etl server, etc), please supply the ${endpoints} variable
for ep in ${endpoints}
do
# Generate CSR for intermediate CA
openssl req -new -newkey rsa:2048 -nodes \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=${ep}ca" \
  -keyout ${ep}ca.key -out ${ep}ca.csr

# Sign intermediate CA by Root CA.
openssl x509 -req -in ${ep}ca.csr -CA ca.crt -CAkey ca.key \
  -extfile <(printf "basicConstraints=CA:TRUE") \
  -days 365 -out ${ep}ca.crt -sha256 -CAcreateserial

# Generate CSR for endpoint
openssl req -new -newkey rsa:2048 -nodes \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=${ep}" \
  -keyout ${ep}.key -out ${ep}.csr

# Sign endpoint certificate by intermediate CA.
openssl x509 -req -in ${ep}.csr -CA ${ep}ca.crt -CAkey ${ep}ca.key \
  -days 365 -out ${ep}.crt -sha256 -CAcreateserial

# combine root and intermediate ca certificates to form a complete chain
cat ${ep}.crt ${ep}ca.crt ca.crt >> ${ep}_chain.crt
 
# create PKCS12 key store
openssl pkcs12 -export -chain -CAfile <(cat ca.crt ${ep}ca.crt) \
  -name ${ep} -in ${ep}.crt -inkey ${ep}.key -out ${ep}.p12 \
  -passout pass:${storepass}
 
# convert PKCS12 to JKS
keytool -importkeystore -alias ${ep} \
  -destkeystore key.jks -deststorepass ${storepass} \
  -srckeystore ${ep}.p12 -srcstoretype pkcs12 -srcstorepass ${storepass}
done
