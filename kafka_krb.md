## Configure Kerberos authentication for Kafka cluster and GPSS

[Kerberos](https://en.wikipedia.org/wiki/Kerberos_(protocol)) protocol provides mutual authentication for Kafka and GPSS. This guide helps you setup minimal Kerberos server and configure Kafka and gpss properly.

Basic explaination for terms we used in this guide:
```
KDC: Key Distribution Center, the Kerberos server.
Pricipal: Equivalent to user name with hostname.
Keytab: A secert file used by clients to authenticate with KDC.
Realm: Local network or domain.
ETL: GPSS runs on this host.
```

If you already have KDC up and running, please skipped to [6. Configure GPSS for Kerberos authentication](#6-configure-gpss-for-kerberos-authentication).

We are using Centos 7 for this guide. The default realm is ```GPDF.CI```. You can replace REALMNAME variable. Please login as root first.

### 0. Prerequisite
```
yum -y install krb5-libs krb5-server krb5-workstation cyrus-sasl-gssapi
```

### 1. Setup KDC

```
export REALMNAME="GPDF.CI"
export HOSTNAME=$(hostname -A)

echo "*/admin@${REALMNAME} *" > /var/kerberos/krb5kdc/kadm5.acl

cat > /var/kerberos/krb5kdc/kdc.conf <<-EOF
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 ${REALMNAME} = {
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
 }
EOF

cat > /etc/krb5.conf <<-EOF
[logging]
default = FILE:/var/log/krb5libs.log
kdc = FILE:/var/log/krb5kdc.log
admin_server = FILE:/var/log/kadmind.log
 
[libdefaults]
default_realm = ${REALMNAME}
dns_lookup_realm = false
dns_lookup_kdc = false
ticket_lifetime = 24h
forwardable = true
rdns = false
pkinit_anchors = /etc/pki/tls/certs/ca-bundle.crt
default_realm = ${REALMNAME}
 
[realms]
${REALMNAME} = {
 kdc = ${HOSTNAME}
 admin_server = ${HOSTNAME}
}
 
[domain_realm]
${HOSTNAME} = ${REALMNAME}
EOF
```

__Copy /etc/krb5.conf to every host needed, including zookeeper, kafka brokers, etl, etc.__

### 2. Create realm and start kdc daemon
```
kdb5_util create -r GPDF.CI -s -P changeme
krb5kdc
```
### 3. Create principals and export keytab
Make sure all principal names are like service/hostname@realm.

In this guide, we assume the cluster setup is 1 zookeeper, 2 kafka brokers, 1 etl server. All running on different hosts. Brokers on the same host can share the same principal.

We are using the following principals:
```
kafka/kafka0@GPDF.CI
kafka/kafka1@GPDF.CI
kafka/etl@GPDF.CI
zookeeper/zookeeper@GPDF.CI
```
Kafka brokers and etl server must has the same service name.

Run these commands to create principals and export keytab:
```
kadmin.local -q "addprinc -randkey kafka/kafka0@GPDF.CI"
kadmin.local -q "addprinc -randkey kafka/kafka1@GPDF.CI"
kadmin.local -q "addprinc -randkey kafka/etl@GPDF.CI"
kadmin.local -q "addprinc -randkey zookeeper/zookeeper@GPDF.CI"
 
kadmin.local -q "ktadd  -norandkey -k /var/kerberos/krb5kdc/kafka0.keytab kafka/kafka0@GPDF.CI"
kadmin.local -q "ktadd  -norandkey -k /var/kerberos/krb5kdc/kafka1.keytab kafka/kafka1@GPDF.CI"
kadmin.local -q "ktadd  -norandkey -k /var/kerberos/krb5kdc/etl.keytab kafka/etl@GPDF.CI"
kadmin.local -q "ktadd  -norandkey -k /var/kerberos/krb5kdc/zookeeper.keytab zookeeper/zookeeper@GPDF.CI"
```

__Copy keytab files to corresponding host.__

### 4. Configure and (re)start zookeeper
Create zookeeper_jaas.conf, replace "/path/to/zookeeper.keytab"
```
Server{
   com.sun.security.auth.module.Krb5LoginModule required
   useKeyTab=true
   storeKey=true
   useTicketCache=false
   keyTab="/path/to/zookeeper.keytab"
   principal="zookeeper/zookeeper@GPDF.CI";
};
```
Edit zookeeper.properties, add following lines
```
authProvider.1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider
requireClientAuthScheme=sasl
jaasLoginRenew=3600000
```
Start zookeeper server, replace paths to the correct location
```
KAFKA_OPTS="-Djava.security.krb5.conf=/etc/krb5.conf -Djava.security.auth.login.config=/path/to/zookeeper_jaas.conf" zookeeper-server-start -daemon /path/to/zookeeper.properties
```

### 5. Configure and (re)start kafka broker
Create a kafka_jaas.conf for each host, make sure principal matches hostname.

Example for kafka0, replace keytab file path here
```
KafkaServer {
   com.sun.security.auth.module.Krb5LoginModule required
   useKeyTab=true
   storeKey=true
   keyTab="/path/to/kafka0.keytab"
   principal="kafka/kafka0@GPDF.CI";
};
 
Client {
   com.sun.security.auth.module.Krb5LoginModule required
   useKeyTab=true
   storeKey=true
   keyTab="/path/to/kafka0.keytab"
   principal="kafka/kafka0@GPDF.CI";
};
```
Edit server.properties.

Configure SASL_PLAINTEXT port number in ```listeners```.

Make sure ```sasl.kerberos.service.name``` is same to first part of each pricipal used for kafka.

```
listeners=PLAINTEXT://:9092,SASL_PLAINTEXT://:9094
sasl.enabled.mechanisms=GSSAPI
sasl.kerberos.service.name=kafka
```

Start kafka broker, and check if SASL port is present
```
KAFKA_OPTS="-Djava.security.krb5.conf=/etc/krb5.conf -Djava.security.auth.login.config=/path/to/kafka_jaas.conf" kafka-server-start -daemon /path/to/server.properties
```

### 6. Configure GPSS for Kerberos authentication

a. If gpss process has access to keytab file
Edit job.yml, add these properties under KAFKA section:
```
KAFKA:
  PROPERTIES:
     security.protocol: SASL_PLAINTEXT
     sasl.kerberos.service.name: kafka
     sasl.kerberos.keytab: /path/to/etl.keytab
     sasl.kerberos.principal: kafka/etl@GPDF.CI
```
b. If gpss process doesn't have access to keytab file
Login with privileged user and obtain a credential cache.
```
kinit -k -t /path/to/etl.keytab kafka/etl@GPDF.CI -c /tmp/etl.cc
```
Give access to gpss user(gpadmin here)
```
chown gpadmin:gpadmin /tmp/etl.cc
```

Set environment variable before starting gpss
```
export KRB5CCNAME=/tmp/etl.cc
```
Check if credential cache is available by runnning ```klist```, example output
```
Ticket cache: FILE:/tmp/etl.cc
Default principal: kafka/etl@GPDF.CI
 
Valid starting     Expires            Service principal
03/11/20 07:31:34  03/12/20 07:31:34  krbtgt/GPDF.CI@GPDF.CI

```
Start gpss in this environment.

Edit job.yml, add these properties under KAFKA section:
```
KAFKA:
  PROPERTIES:
    security.protocol: SASL_PLAINTEXT
    sasl.kerberos.service.name: kafka
    sasl.kerberos.principal: kafka/etl@GPDF.CI
    sasl.kerberos.kinit.cmd:
```