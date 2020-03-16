## Configure Kafka Cluster for SSL connection with GPSS

Basics about SSL and public key certificates
- [Transport Layer Security](https://en.wikipedia.org/wiki/Transport_Layer_Security)
- [Public key infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure)
- [Public key certificate](https://en.wikipedia.org/wiki/Public_key_certificate)

SSL can be used to encrypt communication and mutual authentication between gpss and kafka.

This guide assumes that you haven't configured SSL for kafka cluster before. If SSL for kafka cluster is already enabled and you want to extract key and certificate from JKS for gpss please refer to [Extract private key and certificate from exist JKS](kafka_jks_to_gpss.md)

### 0. Prerequisite
Install openssl and openjdk 1.8.

RHEL/Centos: ```yum install openssl java-1.8.0-openjdk```

Debian/Ubuntu: ```apt install openssl openjdk-8-jdk```

### 1. Generate private keys and certificates for each endpoint
Here endpoint represent hostname of a kafka broker or gpss. For a 2-brokers setup, there are 3 endpoints: ```kafka0, kafka1, etl```. We need a set of key and certificate for each of them.

We will generate certificate like the following structure. 

```
RootCA(ca.crt)
├── kafka0CA (kafka0ca.crt)
│   └──kafka0 (kafka0.crt)
├── kafka1CA (kafka1ca.crt)
│   └──kafka0 (kafka1.crt)
│   ...
├── kafkaNCA
│   └──kafkaN
└── etlCA (etlca.crt)
    └──etl (etl.crt)
```
Skip this step if you have obtained certificate from a well known CA. 

Below is step by step guide to generate needed keys and certificates, ```gencerts/gencerts.bash``` is the full script.

- Generate root certificate authority.
```
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=rootca" \
  -keyout ca.key  -out ca.crt
```

- Generate intermediate CA.
Set $ep variable and do this for each endpoint.
```
openssl req -new -newkey rsa:2048 -nodes \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=${ep}ca" \
  -keyout ${ep}ca.key -out ${ep}ca.csr
```

- Sign intermediate CA by Root CA.
```
openssl x509 -req -in ${ep}ca.csr -CA ca.crt -CAkey ca.key \
  -extfile <(printf "basicConstraints=CA:TRUE") \
  -days 365 -out ${ep}ca.crt -sha256 -CAcreateserial
```
- Generate CSR for endpoint
```
openssl req -new -newkey rsa:2048 -nodes \
  -subj "/C=US/ST=State/L=Locality/O=Pivotal/CN=${ep}" \
  -keyout ${ep}.key -out ${ep}.csr
```
- Sign endpoint certificate by intermediate CA.
```
openssl x509 -req -in ${ep}.csr -CA ${ep}ca.crt -CAkey ${ep}ca.key \
  -days 365 -out ${ep}.crt -sha256 -CAcreateserial
```

### 2. Create the trust store file.
```
yes | keytool -keystore trust.jks -alias ca -importcert -file ca.crt -storepass ${storepass}
```

### 3. Create the key store file
Here we use the same key store file for all brokers. It's possible to use separate store for each broker.

Kafka uses JKS format. We must first put needed keys and certificates into PKCS12 store then convert it to JKS format.

- combine root and intermediate ca certificates to form a complete chain
```
cat ${ep}.crt ${ep}ca.crt ca.crt >> ${ep}_chain.crt
```
- create PKCS12 key store
```
openssl pkcs12 -export -chain -CAfile <(cat ca.crt ${ep}ca.crt) \
  -name ${ep} -in ${ep}_chain.crt -inkey ${ep}.key -out ${ep}.p12 \
  -passout pass:${storepass}
```
- convert PKCS12 to JKS
```
keytool -importkeystore -alias ${ep} \
  -destkeystore key.jks -deststorepass ${storepass} \
  -srckeystore ${ep}.p12 -srcstoretype pkcs12 -srcstorepass ${storepass}
```

Now we have all the files we needed. You can refer to [gencerts](gencerts) folder.

### 4. Edit kafka configuration file
Copy trust.jks, key.jks to kafka broker host.

Add or replace the following properties in kafka broker configuration and restart.
```
advertised.listeners=PLAINTEXT://kafka0:9092,SSL://kafka0:9093
listeners=PLAINTEXT://:9092,SSL://:9093
security.protocol=TLS
ssl.enabled.protocols=TLSv1.2,TLSv1.1,TLSv1
ssl.keystore.type=JKS
ssl.keystore.location=/path/to/key.jks
ssl.keystore.password=******
ssl.truststore.type=JKS
ssl.truststore.location=/path/to/trust.jks
ssl.truststore.password=******
ssl.keymanager.algorithm=PKIX
ssl.client.auth=required
```
If client authentication is not required, you can omit the last line.

### 5. Edit gpss job configuration file
Copy ca.crt, etl.key, etl_chain.crt to gpss server host. If client authentication is not required, only ca.crt is needed.
```
KAFKA:
  PROPERTIES:
    security.protocol=ssl
    ssl.ca.location=/path/to/ca.crt
    ssl.key.location=/path/to/etl.key
    ssl.certificate.location=/path/to/etl_chain.crt
```