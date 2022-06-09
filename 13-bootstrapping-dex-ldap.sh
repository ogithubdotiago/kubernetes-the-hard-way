#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n##############################\n"
printc "# Provisionando Dex/OpenLDAP #\n"
printc "##############################\n"

printc "\n# Aplicando deploy OpenLDAP\n"
    vagrant scp $PATH_LDAP/ldap.yaml master-1:~/
    vagrant ssh master-1 -c "
        kubectl -n kube-system apply -f ldap.yaml
        kubectl -n kube-system wait --for=condition=ready pod -l app=openldap --timeout=60s
    "

printc "\n# Criando OU/User/Group OpenLDAP\n"
    vagrant ssh master-1 -c '
            kubectl -n kube-system exec $(kubectl -n kube-system get pod -l "app=openldap" -o jsonpath="{.items[0].metadata.name}") -- \
                ldapadd -x -D "cn=admin,dc=lab,dc=local" -w admin -H ldap://localhost:389 -f /ldifs/0-ous.ldif
            kubectl -n kube-system exec $(kubectl -n kube-system get pod -l "app=openldap" -o jsonpath="{.items[0].metadata.name}") -- \
                ldapadd -x -D "cn=admin,dc=lab,dc=local" -w admin -H ldap://localhost:389 -f /ldifs/1-users.ldif
            kubectl -n kube-system exec $(kubectl -n kube-system get pod -l "app=openldap" -o jsonpath="{.items[0].metadata.name}") -- \
                ldapadd -x -D "cn=admin,dc=lab,dc=local" -w admin -H ldap://localhost:389 -f /ldifs/2-groups.ldif
    '

printc "\n# Validando User/Group OpenLDAP\n"
    vagrant ssh master-1 -c '
        kubectl -n kube-system exec $(kubectl -n kube-system get pod -l "app=openldap" -o jsonpath="{.items[0].metadata.name}") -- \
            ldapsearch -LLL -x -H ldap://localhost:389 -D "cn=admin,dc=lab,dc=local" -w admin -b "ou=people,dc=lab,dc=local" dn
        kubectl -n kube-system exec $(kubectl -n kube-system get pod -l "app=openldap" -o jsonpath="{.items[0].metadata.name}") -- \
            ldapsearch -LLL -x -H ldap://localhost:389 -D "cn=admin,dc=lab,dc=local" -w admin -b "ou=groups,dc=lab,dc=local" dn
    '

printc "\n# Criando certificado para o Dex/Login\n"
cat << EOF > $PATH_CERT/openssl-login.cnf
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
IP.1 = 192.168.56.40
IP.2 = 192.168.56.21
IP.3 = 192.168.56.22
EOF

openssl genrsa -out $PATH_CERT/ca-login.key 2048
openssl req -x509 -new -nodes -key $PATH_CERT/ca-login.key -days $CERT_DAYS -out $PATH_CERT/ca-login.crt -subj "/CN=kube-ca"
openssl genrsa -out $PATH_CERT/login.key 2048
openssl req -new -key $PATH_CERT/login.key -out $PATH_CERT/login.csr -subj "/CN=kube-ca" -config $PATH_CERT/openssl-login.cnf
openssl x509 -req -in $PATH_CERT/login.csr -CA $PATH_CERT/ca-login.crt -CAkey $PATH_CERT/ca-login.key -CAcreateserial \
    -out $PATH_CERT/login.crt -days $CERT_DAYS -extensions v3_req -extfile $PATH_CERT/openssl-login.cnf
printc "$(ls -1 $PATH_CERT/*login*)\n" "yellow"

printc "\n# Criando secret com certificados\n"
    for file in \
        $PATH_CERT/ca-login.crt \
        $PATH_CERT/login.crt \
        $PATH_CERT/login.key; do
        vagrant scp ${file} master-1:~/
    done
    vagrant ssh master-1 -c "
        kubectl create secret tls dex-tls --cert=login.crt --key=login.key -n kube-system
        sudo mv -v ca-login.crt /var/lib/kubernetes/
    "

printc "\n# Aplicando deploy Dex\n"
    vagrant scp $PATH_DEX/dex.yaml master-1:~/
    vagrant ssh master-1 -c "
        kubectl apply -f dex.yaml -n kube-system
        kubectl -n kube-system wait --for=condition=ready pod -l app=dex --timeout=60s
    "

printc "\n# Validando Dex\n"
    vagrant ssh master-1 -c "
       curl -k https://192.168.56.21:32000/.well-known/openid-configuration
    "

printc "\n# Configurando kube-apiserver com auth oidc\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        GET_INTERNAL_IP=$(vagrant ssh $master -c "bash get_internal_ip.sh")
        INTERNAL_IP="${GET_INTERNAL_IP/$'\r'/}"

cat <<EOF | sudo tee $PATH_CONFIG/kube-apiserver-$master.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.crt \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.crt \\
  --etcd-certfile=/var/lib/kubernetes/etcd-server.crt \\
  --etcd-keyfile=/var/lib/kubernetes/etcd-server.key \\
  --etcd-servers=https://$NET_CIDR.11:2379,https://$NET_CIDR.12:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.crt \\
  --kubelet-client-certificate=/var/lib/kubernetes/kube-apiserver.crt \\
  --kubelet-client-key=/var/lib/kubernetes/kube-apiserver.key \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.crt \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account.key \\
  --service-account-issuer=https://${LB_ADDRESS}:6443 \\
  --service-cluster-ip-range=10.96.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kube-apiserver.crt \\
  --tls-private-key-file=/var/lib/kubernetes/kube-apiserver.key \\
  --oidc-issuer-url=https://$NET_CIDR.21:32000 \\
  --oidc-client-id=gangway \\
  --oidc-ca-file=/var/lib/kubernetes/ca-login.crt \\
  --oidc-username-claim=email \\
  --oidc-groups-claim=groups \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        vagrant scp $PATH_CONFIG/kube-apiserver-$master.service ${master}:~/
        vagrant ssh $master -c "
            sudo mv -v kube-apiserver-$master.service /etc/systemd/system/kube-apiserver.service
            sudo systemctl daemon-reload
            sudo systemctl restart kube-apiserver
        "
    done
