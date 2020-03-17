#!/bin/bash
set -ex

CERT_SET=gencerts
HOSTS_FILE=hosts
SHARED_VOLUME=kafka-shared
STORE_PASS=123456
KEY_STORE=${CERT_SET}/key.jks
TRUST_STORE=${CERT_SET}/trust.jks

if [ -z $1 ]; then
    echo "Need number of kafka nodes"
    exit 1
fi

if [ ! -d $CERT_SET ]; then
    echo $CERT_SET directory not found
    exit 1
fi

function get_container_ip() {
    echo $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $1)
}

function run_container() {
    docker run -v ${SHARED_VOLUME}:/shared -it --name $1 -h $1 -d $2 /bin/bash
    echo $(get_container_ip $1) $1 >> ${HOSTS_FILE}
}

function create_containers() {
    rm -f ${HOSTS_FILE}

    run_container zookeeper kafka
    for ((i=0;i<$1;i++))
    do
       run_container kafka$i kafka
    done
    run_container krb krb
    run_container etl krb
}

function setup_interconnect() {
    hosts=$(awk '{print $2;}' < ${HOSTS_FILE})
    for host in $hosts
    do
        docker exec -i $host bash -c 'cat >> /etc/hosts' < ${HOSTS_FILE}
    done
}

function create_principal() {
    docker exec krb kadmin.local -q "addprinc -randkey $1/$2@GPDF.CI"
    docker exec krb kadmin.local -q "ktadd  -norandkey -k /shared/$3.keytab $1/$2@GPDF.CI"
}

function setup_kerberos() {
    docker cp setup_kerberos.bash krb:/
    docker exec -e REALMNAME="GPDF.CI" krb /setup_kerberos.bash
    docker exec krb cp /etc/krb5.conf /shared/

    docker exec -i krb bash <<-EOF
kdb5_util create -r GPDF.CI -s -P changeme
krb5kdc
EOF
    create_principal zookeeper zookeeper zookeeper
    create_principal krb krb krb
    create_principal kafka etl etl

    for ((i=0; i<$1; i++))
    do
        create_principal kafka kafka$i kafka$i
    done
}

function setup_kafka_cluster() {
    docker cp zookeeper.properties zookeeper:/
    docker cp zookeeper_jaas.conf zookeeper:/

    docker exec -e KAFKA_OPTS="-Djava.security.krb5.conf=/shared/krb5.conf -Djava.security.auth.login.config=/zookeeper_jaas.conf" \
        zookeeper zookeeper-server-start -daemon /zookeeper.properties
    for ((i=0; i<$1; i++))
    do
        SERVER_CONFIG=server.properties.$i
        cp server.properties ${SERVER_CONFIG}
        echo "broker.id=$i" >> ${SERVER_CONFIG}
        echo "advertised.listeners=PLAINTEXT://kafka$i:9092,SSL://kafka$i:9093,SASL_PLAINTEXT://kafka$i:9094,SASL_SSL://kafka$i:9095" >> ${SERVER_CONFIG}
        echo "listeners=PLAINTEXT://:9092,SSL://:9093,SASL_PLAINTEXT://:9094,SASL_SSL://:9095" >> ${SERVER_CONFIG}
        echo "ssl.keystore.password=${STORE_PASS}" >> ${SERVER_CONFIG}
        echo "ssl.truststore.password=${STORE_PASS}" >> ${SERVER_CONFIG}

        docker cp ${SERVER_CONFIG} kafka$i:/server.properties
        docker cp ${KEY_STORE} kafka$i:/
        docker cp ${TRUST_STORE} kafka$i:/

        rm ${SERVER_CONFIG}
        docker exec -i kafka$i bash -c 'cat > /kafka_jaas.conf' <<-EOF
KafkaServer {
    com.sun.security.auth.module.Krb5LoginModule required
    useKeyTab=true
    storeKey=true
    keyTab="/shared/kafka$i.keytab"
    principal="kafka/kafka$i@GPDF.CI";
};

Client {
    com.sun.security.auth.module.Krb5LoginModule required
    useKeyTab=true
    storeKey=true
    keyTab="/shared/kafka$i.keytab"
    principal="kafka/kafka$i@GPDF.CI";
};
EOF
        docker exec -e KAFKA_OPTS="-Djava.security.krb5.conf=/shared/krb5.conf -Djava.security.auth.login.config=/kafka_jaas.conf" \
            kafka$i kafka-server-start -daemon /server.properties
    done
}

function generate_certs() {
    pushd ${CERT_SET}
    ENDPOINTS=kafka0
    for ((i=1; i<$1; i++))
    do
        ENDPOINTS="${ENDPOINTS} kafka${i}"
    done
    endpoints=${ENDPOINTS} storepass=${STORE_PASS} ./gencerts.bash
    popd
}

docker volume create ${SHARED_VOLUME}
generate_certs $1 ${STORE_PASS}
create_containers $1
setup_interconnect
setup_kerberos $1
setup_kafka_cluster $1
