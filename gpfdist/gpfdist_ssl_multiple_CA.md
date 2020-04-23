The gpfdists protocol is a secure version of the gpfdist protocol that securely identifies the file server and the Greenplum Database and encrypts the communications between them.
Please make sure that you have read [Encrypting gpfdist Connections](http://docs.greenplum.org/6-4/security-guide/topics/Encryption.html#gpfdist_connections) in Greenplum database documentation before using this guide.

## Scenario overview:

![alt text](multiple_CA_scenario.png)

## Prepare private keys and certificates

Prepare SSL certificate folder for server1 and server2 
	server1: ${path_of_server1_cert}
	server2: ${path_of_server2_cert}

1. Generate by yourself, server1 and server2 use the same root CA

    - Generate root certificate and intermediate certificate, in ${path_of_server1_cert}
    run gen_root_cert.bash

    - Generate server and client certificates for server1
    run gen_sc_certs.bash server1 client1

    - Copy root and intermediate CA to  ${path_of_server2_cert} and generate server and client certificates for server2
    run gen_sc_certs.bash server2 client2

2. Generate by yourself, server1 and server2 use different root CA

    - Generate root, intermediate, server and client certificate for server1 in  ${path_of_server1_cert}
    run gen_all_certs.bash rootca1 interca1 server1 client1

    - Generate root, intermediate, server and client certificate for server2, in  ${path_of_server2_cert}
    run gen_all_certs.bash rootca2 interca2 server2 client2

    - Merge server1 and server2 root CA
    > cat ${path_of_server1_cert}/root.crt >> ${path_of_server2_cert}/root.crt
    > cp ${path_of_server2_cert}/root.crt ${path_of_server1_cert}/root.crt

3. Obtain from a well known provider

    Instead of generating yourself, you also can send a Certificate Signing Request(CSR) to the provider and obtain the corresponding certificate signed by them, along with the whole certificate chain. 
	You need to merge server1 and server2 root CA too, if they are different.




