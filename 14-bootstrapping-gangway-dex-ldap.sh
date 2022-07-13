#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n######################################\n"
printc "# Provisionando OpenLDAP/Dex/Gangway #\n"
printc "######################################\n"

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

printc "\n# Criando secret com certificados Dex\n"
    for file in \
        $PATH_CERT/ca-login.crt \
        $PATH_CERT/login.crt \
        $PATH_CERT/login.key; do
        vagrant scp ${file} master-1:~/
    done
    vagrant ssh master-1 -c "
        kubectl create secret tls dex-tls --cert=login.crt --key=login.key -n kube-system
        kubectl create secret generic dex-ca --from-file=ca-login.crt=ca-login.crt -n kube-system
    "

printc "\n# Aplicando deploy Dex\n"
    vagrant scp $PATH_DEX/dex.yaml master-1:~/
    vagrant ssh master-1 -c "
        kubectl apply -f dex.yaml -n kube-system
        kubectl -n kube-system wait --for=condition=ready pod -l app=dex --timeout=60s
    "

printc "\n# Validando Dex\n"
    vagrant ssh master-1 -c "
       curl -k https://$IP_LB_WORKER:32000/.well-known/openid-configuration
    "

printc "\n# Aplicando deploy Gangway\n"
    vagrant scp $PATH_GANGWAY/gangway.yaml master-1:~/
    vagrant ssh master-1 -c "
        kubectl apply -f gangway.yaml -n kube-system
        kubectl -n kube-system wait --for=condition=ready pod -l app=gangway --timeout=60s
    "

printc "\n# Criando RBAC para sre@lab.local\n"
cat <<EOF | sudo tee $PATH_CONFIG/clusterrolebinding-sre-edit.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sre-edit
subjects:
- kind: User
  name: sre@lab.local
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
EOF
printc "$(ls -1 $PATH_CONFIG/clusterrole-sre-edit.yaml)\n" "yellow"

printc "\n# Criando RBAC para dev@lab.local\n"
cat <<EOF | sudo tee $PATH_CONFIG/clusterrolebinding-dev-view.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dev-view
subjects:
- kind: User
  name: dev@lab.local
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF
printc "$(ls -1 $PATH_CONFIG/clusterrolebinding-dev-view.yaml)\n" "yellow"

    for file in \
        $PATH_CONFIG/clusterrolebinding-sre-edit.yaml \
        $PATH_CONFIG/clusterrolebinding-dev-view.yaml; do
        vagrant scp ${file} master-1:~/
    done
    vagrant ssh master-1 -c "
        kubectl apply -f clusterrolebinding-sre-edit.yaml
        kubectl apply -f clusterrolebinding-dev-view.yaml
    "
