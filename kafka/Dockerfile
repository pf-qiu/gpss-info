FROM ubuntu:18.04
ADD confluent-oss-5.0.0-2.11.tar.gz /
RUN sed -i -e "s/archive.ubuntu.com/jp.archive.ubuntu.com/g" /etc/apt/sources.list
RUN apt update
RUN apt -y install openjdk-8-jdk iputils-ping net-tools krb5-user vim
ENV PATH /confluent-5.0.0/bin/:$PATH

