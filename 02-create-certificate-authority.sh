#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n###################################################\n"
printc "# Provisionando uma CA e gerando Certificados TLS #\n"
printc "###################################################\n"

printc "\n# Criando CA para ser usada para gerar certificados TLS adicionais\n"
    openssl genrsa -out $PATH_CERT/ca.key 2048
    openssl req -new -key $PATH_CERT/ca.key -subj "/CN=KUBERNETES-CA" -out $PATH_CERT/ca.csr
    openssl x509 -req -in $PATH_CERT/ca.csr -signkey $PATH_CERT/ca.key -CAcreateserial -out $PATH_CERT/ca.crt -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/ca*)\n" "yellow"

printc "\n# Criando certificado para o admin\n"
    openssl genrsa -out $PATH_CERT/admin.key 2048
    openssl req -new -key $PATH_CERT/admin.key -subj "/CN=admin/O=system:masters" -out $PATH_CERT/admin.csr
    openssl x509 -req -in $PATH_CERT/admin.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial -out $PATH_CERT/admin.crt -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/admin*)\n" "yellow"

printc "\n# Criando certificado para o kube-controller-manager\n"
    openssl genrsa -out $PATH_CERT/kube-controller-manager.key 2048
    openssl req -new -key $PATH_CERT/kube-controller-manager.key -subj "/CN=system:kube-controller-manager" -out $PATH_CERT/kube-controller-manager.csr
    openssl x509 -req -in $PATH_CERT/kube-controller-manager.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial \
        -out $PATH_CERT/kube-controller-manager.crt -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/kube-controller-manager*)\n" "yellow"

printc "\n# Criando certificado para o kube-scheduler\n"
    openssl genrsa -out $PATH_CERT/kube-scheduler.key 2048
    openssl req -new -key $PATH_CERT/kube-scheduler.key -subj "/CN=system:kube-scheduler" -out $PATH_CERT/kube-scheduler.csr
    openssl x509 -req -in $PATH_CERT/kube-scheduler.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial \
        -out $PATH_CERT/kube-scheduler.crt -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/kube-scheduler*)\n" "yellow"

printc "\n# Criando certificado para o kube-apiserver\n"
    cat <<-EOF | sudo tee $PATH_CERT/openssl.cnf
	[req]
	req_extensions = v3_req
	distinguished_name = req_distinguished_name
	[req_distinguished_name]
	[ v3_req ]
	basicConstraints = CA:FALSE
	keyUsage = nonRepudiation, digitalSignature, keyEncipherment
	subjectAltName = @alt_names
	[alt_names]
	DNS.1 = kubernetes
	DNS.2 = kubernetes.default
	DNS.3 = kubernetes.default.svc
	DNS.4 = kubernetes.default.svc.cluster.local
	IP.1 = $IP_SVC_K8S
	IP.2 = $NET_CIDR.11
	IP.3 = $NET_CIDR.12
	IP.4 = $NET_CIDR.30
	IP.5 = 127.0.0.1
	EOF
    openssl genrsa -out $PATH_CERT/kube-apiserver.key 2048
    openssl req -new -key $PATH_CERT/kube-apiserver.key -subj "/CN=kube-apiserver" -out $PATH_CERT/kube-apiserver.csr -config $PATH_CERT/openssl.cnf
    openssl x509 -req -in $PATH_CERT/kube-apiserver.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial \
        -out $PATH_CERT/kube-apiserver.crt -extensions v3_req -extfile $PATH_CERT/openssl.cnf -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/kube-apiserver*)\n" "yellow"
    printc "$(ls -1 $PATH_CERT/openssl.cnf)\n" "yellow"

printc "\n# Criando certificado para o etcd-server\n"
    cat <<-EOF | sudo tee $PATH_CERT/openssl-etcd.cnf
	[req]
	req_extensions = v3_req
	distinguished_name = req_distinguished_name
	[req_distinguished_name]
	[ v3_req ]
	basicConstraints = CA:FALSE
	keyUsage = nonRepudiation, digitalSignature, keyEncipherment
	subjectAltName = @alt_names
	[alt_names]
	IP.1 = $NET_CIDR.11
	IP.2 = $NET_CIDR.12
	IP.3 = 127.0.0.1
	EOF
    openssl genrsa -out $PATH_CERT/etcd-server.key 2048
    openssl req -new -key $PATH_CERT/etcd-server.key -subj "/CN=etcd-server" -out $PATH_CERT/etcd-server.csr -config $PATH_CERT/openssl-etcd.cnf
    openssl x509 -req -in $PATH_CERT/etcd-server.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial \
        -out $PATH_CERT/etcd-server.crt -extensions v3_req -extfile $PATH_CERT/openssl-etcd.cnf -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/etcd-server*)\n" "yellow"
    printc "$(ls -1 $PATH_CERT/openssl-etcd.cnf)\n" "yellow"

printc "\n# Criando certificado para o service-account\n"
    openssl genrsa -out $PATH_CERT/service-account.key 2048
    openssl req -new -key $PATH_CERT/service-account.key -subj "/CN=service-accounts" -out $PATH_CERT/service-account.csr
    openssl x509 -req -in $PATH_CERT/service-account.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial \
        -out $PATH_CERT/service-account.crt -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/service-account*)\n" "yellow"

printc "\n# Criando certificado para o Dex\n"
    cat <<-EOF | sudo tee $PATH_CERT/openssl-login.cnf
	[req]
	req_extensions = v3_req
	distinguished_name = req_distinguished_name
	[req_distinguished_name]
	[ v3_req ]
	basicConstraints = CA:FALSE
	keyUsage = nonRepudiation, digitalSignature, keyEncipherment
	subjectAltName = @alt_names
	[alt_names]
	DNS.1 = dex.lab.local
	DNS.2 = login.lab.local
	IP.1 = $IP_LB_WORKER
	IP.2 = $NET_CIDR.21
	IP.3 = $NET_CIDR.22
	EOF
    openssl genrsa -out $PATH_CERT/ca-login.key 2048
    openssl req -x509 -new -nodes -key $PATH_CERT/ca-login.key -days $CERT_DAYS -out $PATH_CERT/ca-login.crt -subj "/CN=kube-ca"
    openssl genrsa -out $PATH_CERT/login.key 2048
    openssl req -new -key $PATH_CERT/login.key -out $PATH_CERT/login.csr -subj "/CN=kube-ca" -config $PATH_CERT/openssl-login.cnf
    openssl x509 -req -in $PATH_CERT/login.csr -CA $PATH_CERT/ca-login.crt -CAkey $PATH_CERT/ca-login.key -CAcreateserial \
        -out $PATH_CERT/login.crt -days $CERT_DAYS -extensions v3_req -extfile $PATH_CERT/openssl-login.cnf
    printc "$(ls -1 $PATH_CERT/openssl-login.cnf)\n" "yellow"
    printc "$(ls -1 $PATH_CERT/login*)\n" "yellow"
