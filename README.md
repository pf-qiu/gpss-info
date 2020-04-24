## GPSS info
Official [documentation](https://gpdb.docs.pivotal.io/streaming-server/latest/intro.html) for GPSS.

GPSS supports Kafka with SSL and SASL(Kerberos) enabled. Here is some information about how to properly setup and configure Kafka cluster.

- [Configure SSL for Kafka Cluster](kafka_ssl.md)
- [Extract private key and certificate from exist JKS](kafka_jks_to_gpss.md)
- [Configure Kerberos authentication for Kafka cluster and GPSS](kafka_krb.md)
- [Enable both SSL and Kerberos at the same time](kafka_krb_ssl.md)

If you have openssl, openjdk-1.8, docker installed, you can clone this repo and run following command to quickly setup a cluster with zookeeper, 4 kafka brokers, kdc.
```
./start_kafka_cluster.bash 4
```

If you have question about gpfdist SSL connection, please refer to the following documentation:

- [configure gpfdists connection with multiple certificates](gpfdist/README.md)