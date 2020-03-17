#!/bin/bash

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