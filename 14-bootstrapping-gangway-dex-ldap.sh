#!/bin/bash

# Referencia:
# - https://jekhokie.github.io/k8s/dex/ldap/auth/gangway/oidc/2020/04/28/k8s-dex-ldap-oidc.html
# - https://github.com/brightzheng100/kubernetes-dex-ldap-integration

source $(dirname $0)/00-include.sh

printc "\n######################################\n"
printc "# Provisionando OpenLDAP/Dex/Gangway #\n"
printc "######################################\n"

printc "\n# Aplicando deploy OpenLDAP\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/ldap.yaml
	apiVersion: v1
	kind: Service
	metadata:
	  name: openldap
	  labels:
	    app: openldap
	spec:
	  type: ClusterIP
	  ports:
	    - name: tcp-ldap
	      port: 389
	      targetPort: tcp-ldap
	  selector:
	    app: openldap
	---
	apiVersion: apps/v1
	kind: Deployment
	metadata:
	  name: openldap
	  labels:
	    app: openldap
	spec:
	  selector:
	    matchLabels:
	      app: openldap
	  replicas: 1
	  template:
	    metadata:
	      labels:
	        app: openldap
	    spec:
	      containers:
	        - name: openldap
	          image: osixia/openldap:$OPENLDAP_VERSION
	          imagePullPolicy: "Always"
	          env:
	            - name: LDAP_ORGANISATION
	              value: "Lab Inc."
	            - name: LDAP_DOMAIN
	              value: "lab.local"
	            - name: LDAP_ADMIN_USERNAME
	              value: "admin"
	            - name: LDAP_ADMIN_PASSWORD
	              value: "admin"
	          ports:
	            - name: tcp-ldap
	              containerPort: 389
	          volumeMounts:
	          - name: ldap-ldif
	            mountPath: /ldifs/
	      volumes:
	      - name: ldap-ldif
	        configMap:
	          name: openldap
	---
	apiVersion: v1
	kind: ConfigMap
	metadata:
	  name: openldap
	  labels:
	    app: openldap
	data:
	  0-ous.ldif: |-
	    dn: ou=people,dc=lab,dc=local
	    ou: people
	    description: All people in organisation
	    objectclass: organizationalunit
	
	    dn: ou=groups,dc=lab,dc=local
	    objectClass: organizationalUnit
	    ou: groups
	  1-users.ldif: |-
	    dn: cn=sre,ou=people,dc=lab,dc=local
	    objectClass: inetOrgPerson
	    sn: sre
	    cn: sre
	    uid: sre
	    mail: sre@lab.local
	    userPassword: {SSHA}RRN6AM9u0tpTEOn6oBcIt9X3BbFPKVk5
	
	    dn: cn=dev,ou=people,dc=lab,dc=local
	    objectClass: inetOrgPerson
	    sn: dev
	    cn: dev
	    uid: dev
	    mail: dev@lab.local
	    userPassword: {SSHA}RRN6AM9u0tpTEOn6oBcIt9X3BbFPKVk5
	  2-groups.ldif: |-
	    dn: cn=sres,ou=groups,dc=lab,dc=local
	    objectClass: groupOfNames
	    cn: sres
	    member: cn=sre,ou=people,dc=lab,dc=local
	
	    dn: cn=devs,ou=groups,dc=lab,dc=local
	    objectClass: groupOfNames
	    cn: devs
	    member: cn=dev,ou=people,dc=lab,dc=local
	EOF
    printc "$(ls -1 $PATH_CONFIG/ldap.yaml)\n" "yellow"

    vagrant scp $PATH_CONFIG/ldap.yaml master-1:~/
    vagrant ssh master-1 -c "
        kubectl -n kube-system apply -f ldap.yaml
        kubectl -n kube-system wait --for=condition=ready pod -l app=openldap --timeout=60s
        sleep 30
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
    cat <<-EOF | sudo tee $PATH_CONFIG/dex.yaml
	apiVersion: v1
	kind: ServiceAccount
	metadata:
	  name: dex
	  labels:
	    app: dex
	---
	apiVersion: rbac.authorization.k8s.io/v1
	kind: ClusterRole
	metadata:
	  name: dex
	  labels:
	    app: dex
	rules:
	- apiGroups: ["dex.coreos.com"]
	  resources: ["*"]
	  verbs: ["*"]
	- apiGroups: ["apiextensions.k8s.io"]
	  resources: ["customresourcedefinitions"]
	  verbs: ["create"]
	---
	apiVersion: rbac.authorization.k8s.io/v1
	kind: ClusterRoleBinding
	metadata:
	  name: dex
	  labels:
	    app: dex
	roleRef:
	  apiGroup: rbac.authorization.k8s.io
	  kind: ClusterRole
	  name: dex
	subjects:
	- kind: ServiceAccount
	  name: dex
	  namespace: kube-system
	---
	apiVersion: apps/v1
	kind: Deployment
	metadata:
	  name: dex
	  labels:
	    app: dex
	spec:
	  replicas: 1
	  selector:
	    matchLabels:
	      app: dex
	  template:
	    metadata:
	      labels:
	        app: dex
	    spec:
	      serviceAccountName: dex
	      containers:
	      - image: ghcr.io/dexidp/dex:$DEX_VERSION
	        name: dex
	        command: ["/usr/local/bin/dex", "serve", "/etc/dex/cfg/config.yaml"]
	        ports:
	        - name: https
	          containerPort: 5556
	        volumeMounts:
	        - name: dex-config
	          mountPath: /etc/dex/cfg
	        - name: dex-tls
	          mountPath: /etc/dex/tls
	      volumes:
	      - name: dex-config
	        configMap:
	          name: dex-config
	          items:
	          - key: config.yaml
	            path: config.yaml
	      - name: dex-tls
	        secret:
	          secretName: dex-tls
	---
	kind: ConfigMap
	apiVersion: v1
	metadata:
	  name: dex-config
	  labels:
	    app: dex
	data:
	  config.yaml: |
	    issuer: https://$IP_LB_WORKER:32000
	    storage:
	      type: kubernetes
	      config:
	        inCluster: true
	    web:
	      https: 0.0.0.0:5556
	      tlsCert: /etc/dex/tls/tls.crt
	      tlsKey: /etc/dex/tls/tls.key
	    connectors:
	    - type: ldap
	      name: OpenLDAP
	      id: ldap
	      config:
	        host: openldap.kube-system.svc:389
	        insecureNoSSL: true
	        bindDN: cn=admin,dc=lab,dc=local
	        bindPW: admin
	        usernamePrompt: Email Address
	        userSearch:
	          baseDN: ou=people,dc=lab,dc=local
	          filter: "(objectclass=inetOrgPerson)"
	          username: mail
	          idAttr: DN
	          emailAttr: mail
	          nameAttr: cn
	        groupSearch:
	          baseDN: ou=groups,dc=lab,dc=local
	          filter: "(objectClass=groupOfNames)"
	          userMatchers:
	          - userAttr: DN
	            groupAttr: member
	          nameAttr: cn
	    oauth2:
	      skipApprovalScreen: true
	    staticClients:
	    - id: gangway
	      redirectURIs:
	      - 'http://$IP_LB_WORKER:32001/callback'
	      name: 'gangway'
	      secret: ZXhhbXBsZS1hcHAtc2VjcmV0
	---
	apiVersion: v1
	kind: Service
	metadata:
	  name: dex
	  labels:
	    app: dex
	spec:
	  type: NodePort
	  ports:
	  - name: dex
	    port: 5556
	    protocol: TCP
	    targetPort: 5556
	    nodePort: 32000
	  selector:
	    app: dex
	EOF
    printc "$(ls -1 $PATH_CONFIG/dex.yaml)\n" "yellow"

    vagrant scp $PATH_CONFIG/dex.yaml master-1:~/
    vagrant ssh master-1 -c "
        kubectl apply -f dex.yaml -n kube-system
        sleep 5
        kubectl -n kube-system wait --for=condition=ready pod -l app=dex --timeout=60s
        sleep 30
    "

printc "\n# Validando Dex\n"
    vagrant ssh master-1 -c "
       curl -k https://$IP_LB_WORKER:32000/.well-known/openid-configuration
    "

printc "\n# Aplicando deploy Gangway\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/gangway.yaml
	apiVersion: v1
	kind: ConfigMap
	metadata:
	  name: gangway
	  labels:
	    app: gangway
	data:
	  gangway.yaml: |
	    clusterName: "$CLUSTER_NAME"
	    authorizeURL: "https://$IP_LB_WORKER:32000/auth"
	    tokenURL: "https://$IP_LB_WORKER:32000/token"
	    redirectURL: "http://$IP_LB_WORKER:32001/callback"
	    clientID: "gangway"
	    clientSecret: ZXhhbXBsZS1hcHAtc2VjcmV0
	    usernameClaim: "sub"
	    emailClaim: "email"
	    apiServerURL: https://$IP_LB_MASTER:6443
	    trustedCAPath: /cacerts/ca-login.crt
	    allowEmptyClientSecret: true
	    scopes: ["groups", "openid", "profile", "email", "offline_access"]
	    customHTMLTemplatesDir: /templates/
	---
	apiVersion: v1
	kind: Secret
	metadata:
	  name: gangway-key
	  labels:
	    app: gangway
	type: Opaque
	stringData:
	  sessionkey: secretgangwaysecret
	---
	apiVersion: apps/v1
	kind: Deployment
	metadata:
	  name: gangway
	  labels:
	    app: gangway
	spec:
	  replicas: 1
	  selector:
	    matchLabels:
	      app: gangway
	  template:
	    metadata:
	      labels:
	        app: gangway
	    spec:
	      containers:
	        - name: gangway
	          image: gcr.io/heptio-images/gangway:$GANGWAY_VERSION
	          imagePullPolicy: Always
	          command: ["gangway", "-config", "/gangway/gangway.yaml"]
	          env:
	            - name: GANGWAY_SESSION_SECURITY_KEY
	              valueFrom:
	                secretKeyRef:
	                  name: gangway-key
	                  key: sessionkey
	          ports:
	            - containerPort: 8080
	              protocol: TCP
	          volumeMounts:
	            - name: gangway
	              mountPath: /gangway/
	            - name: gangway-templates
	              mountPath: /templates/
	            - name: dex-ca
	              mountPath: /cacerts/
	          livenessProbe:
	            httpGet:
	              path: /
	              port: 8080
	            initialDelaySeconds: 20
	            timeoutSeconds: 1
	            periodSeconds: 60
	            failureThreshold: 3
	          readinessProbe:
	            httpGet:
	              path: /
	              port: 8080
	            timeoutSeconds: 1
	            periodSeconds: 10
	            failureThreshold: 3
	      volumes:
	        - name: gangway
	          configMap:
	            name: gangway
	        - name: gangway-templates
	          configMap:
	            name: gangway-templates
	        - name: dex-ca
	          secret:
	            secretName: dex-ca
	---
	apiVersion: v1
	kind: Service
	metadata:
	  name: gangwaysvc
	  labels:
	    app: gangway
	spec:
	  type: NodePort
	  ports:
	  - port: 8080
	    protocol: TCP
	    targetPort: 8080
	    nodePort: 32001
	  selector:
	    app: gangway
	EOF
    printc "$(ls -1 $PATH_CONFIG/gangway.yaml)\n" "yellow"

    for file in \
        $PATH_CONFIG/gangway.yaml \
        $PATH_CONFIG/templates/home.tmpl \
        $PATH_CONFIG/templates/commandline.tmpl; do
        vagrant scp ${file} master-1:~/
    done
    vagrant ssh master-1 -c "
        kubectl create configmap gangway-templates --from-file commandline.tmpl --from-file home.tmpl
        kubectl apply -f gangway.yaml -n kube-system
        kubectl -n kube-system wait --for=condition=ready pod -l app=gangway --timeout=60s
    "

printc "\n# Criando RBAC para sre@lab.local\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/clusterrolebinding-sre-edit.yaml
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
    cat <<-EOF | sudo tee $PATH_CONFIG/clusterrolebinding-dev-view.yaml
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
 
printc "\n# Autenticando no cluster\n"

printc "\nurl:\n" "yellow"
echo "-----------------------------------------"
echo "|  url  |  http://192.168.56.40:32001/  |" 
echo "-----------------------------------------"

printc "\nusers:\n" "yellow"
echo "--------------------------------"
echo "|     email     |   password   |" 
echo "--------------------------------"
echo "| sre@lab.local |    secret    |"
echo "--------------------------------"
echo "| dev@lab.local |    secret    |"
echo "--------------------------------"
