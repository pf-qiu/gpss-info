# Extract private key and certificate from exist JKS

When you have already created JKS needed for kafka,  you can use one of the keys in JKS for gpss provided that the common name of corresponding certificate matches the host where gpss is running.

If client authentication is not required, only trusted certificates(ca.crt) is needed.

### 0. Prerequisite
Install openssl and openjdk 1.8.

RHEL/Centos: ```yum install openssl java-1.8.0-openjdk```

Debian/Ubuntu: ```apt install openssl openjdk-8-jdk```

### 1. Find the key store and trust store file in kafka.properties
```
ssl.keystore.location=/path/to/key.jks
ssl.truststore.location=/path/to/trust.jks
```
### 2. Extract trusted certificates from trust.jks
```
keytool -list -rfc -keystore trust.jks -storepass ${storepass} > ca.crt
```
ca.crt is the trusted certificate file and should contain root certificate for all endpoints.

### 3. Find private key to be used
First list all available keys
```
keytool -list -keystore key.jks -storepass ${storepass} | grep PrivateKeyEntry
```
Example output:
```
etl, Mar 16, 2020, PrivateKeyEntry, 
kafka1, Mar 16, 2020, PrivateKeyEntry, 
kafka0, Mar 16, 2020, PrivateKeyEntry,
```
Select the private key you want gpss to use.

### 4. Extract key pair to PKCS12 store
Assuming "etl" is choosen here.
```
keytool -importkeystore -alias etl -srckeystore key.jks -srcstorepass ${storepass} \
-destkeystore etl.p12 -deststorepass ${storepass} -deststoretype pkcs12
```

### 5. Extract private key
If you want to set passphrase for it, remove "-nodes" option.
```
openssl pkcs12 -nocerts -in etl.p12 -nodes -out etl.key -passin pass:${storepass}
```
etl.key is the private key file to be used.

### 6. Extract and verify certificate chain
```
openssl pkcs12 -nokeys -in etl.p12 -out etl_chain.crt -passin pass:${storepass}
openssl verify -trusted ca.crt -untrusted etl_chain.crt -show_chain < etl_chain.crt
```
Example output:
```
stdin: OK
Chain:
depth=0: C = US, ST = State, L = Locality, O = Pivotal, CN = etl (untrusted)
depth=1: C = US, ST = State, L = Locality, O = Pivotal, CN = etlca (untrusted)
depth=2: C = US, ST = State, L = Locality, O = Pivotal, CN = rootca
```
If the result is not OK, something is wrong, probably due to incomplete chain or rootca mismatch.

### 7. Edit gpss job configuration file
Copy ca.crt, etl.key, etl_chain.crt to gpss server host.
```
KAFKA:
  PROPERTIES:
    security.protocol=ssl
    ssl.ca.location=/path/to/ca.crt
    ssl.key.location=/path/to/etl.key
    ssl.certificate.location=/path/to/etl_chain.crt
```