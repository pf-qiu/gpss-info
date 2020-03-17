## Enable both SSL and Kerberos for Kafka broker

Kafka support SSL over Kerberos authentication. This guide show how to configure kafka and gpss to communicate with both enabled. Please go through individual setup for [SSL](kafka_ssl.md) and [Kerberos](kafka_krb.md) first.

### Configure SASL_SSL for kafka broker

Edit server.properties.

Configure SASL_SSL port number in ```listeners```, and related properties from SSL and Kerberos configuration.
```
listeners=PLAINTEXT://:9092,SASL_SSL://:9095
sasl.enabled.mechanisms=GSSAPI
sasl.kerberos.service.name=kafka
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
Restart kafka broker and check if SASL_SSL port is present

### Configure GPSS job
Edit job.yml, add these properties under KAFKA section:
```
KAFKA:
  PROPERTIES:
    security.protocol: sasl_ssl
    sasl.kerberos.service.name: kafka
    sasl.kerberos.keytab: /path/to/etl.keytab
    sasl.kerberos.principal: kafka/etl@GPDF.CI
    ssl.ca.location=/path/to/ca.crt
    ssl.key.location=/path/to/etl.key
    ssl.certificate.location=/path/to/etl_chain.crt
```
