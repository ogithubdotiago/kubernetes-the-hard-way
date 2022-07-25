#!/bin/bash

# Referencia:
# - https://projectcalico.docs.tigera.io/getting-started/kubernetes/hardway/

source $(dirname $0)/00-include.sh

printc "\n#####################################\n"
printc "# Configurando Pod Network - Calico #\n"
printc "#####################################\n"

printc "\n# Instalando Calico Custom Resources\n"
    vagrant ssh master-1 -c " 
        kubectl apply -f https://projectcalico.docs.tigera.io/manifests/crds.yaml
    "

printc "\n# Instalando calicoctl $CALICO_VERSION\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c "
            wget https://github.com/projectcalico/calicoctl/releases/download/$CALICO_VERSION/calicoctl
            chmod -v +x calicoctl
            sudo mv -v calicoctl /usr/local/bin/
            export KUBECONFIG=~/.kube/config
            export DATASTORE_TYPE=kubernetes
        "
    done
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c "
            wget https://github.com/projectcalico/calicoctl/releases/download/$CALICO_VERSION/calicoctl
            chmod -v +x calicoctl
            sudo mv -v calicoctl /usr/local/bin/
            export KUBECONFIG=~/.kube/config
            export DATASTORE_TYPE=kubernetes
        "
    done

printc "\n# Criando IP pool\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/ippool.yaml
	apiVersion: projectcalico.org/v3
	kind: IPPool
	metadata:
	  name: default-ippool
	spec:
	  cidr: $NET_CIDR_POD
	  ipipMode: Never
	  natOutgoing: true
	  disabled: false
	  nodeSelector: all()
	EOF
    printc "$(ls -1 $PATH_CONFIG/ippool.yaml)\n" "yellow"

    vagrant scp $PATH_CONFIG/ippool.yaml master-1:~/
    vagrant ssh master-1 -c "
        calicoctl create -f ippool.yaml
    "

printc "\n# Criando certificados para o CNI plugin e Typha\n"
    openssl req -newkey rsa:4096 -keyout $PATH_CERT/cni.key -nodes -out $PATH_CERT/cni.csr -subj "/CN=calico-cni"
    openssl x509 -req -in $PATH_CERT/cni.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial -out $PATH_CERT/cni.crt -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/cni*)\n" "yellow"

    openssl req -x509 -newkey rsa:4096 -keyout $PATH_CERT/typhaca.key -nodes -out $PATH_CERT/typhaca.crt -subj "/CN=Calico Typha CA" -days $CERT_DAYS
    openssl req -newkey rsa:4096 -keyout $PATH_CERT/typha.key -nodes -out $PATH_CERT/typha.csr -subj "/CN=calico-typha"
    openssl x509 -req -in $PATH_CERT/typha.csr -CA $PATH_CERT/typhaca.crt -CAkey $PATH_CERT/typhaca.key -CAcreateserial -out $PATH_CERT/typha.crt -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/typha*)\n" "yellow"

    openssl req -newkey rsa:4096 -keyout $PATH_CERT/calico-node.key -nodes -out $PATH_CERT/calico-node.csr -subj "/CN=calico-node"
    openssl x509 -req -in $PATH_CERT/calico-node.csr -CA $PATH_CERT/typhaca.crt -CAkey $PATH_CERT/typhaca.key -CAcreateserial \
        -out $PATH_CERT/calico-node.crt -days $CERT_DAYS
    printc "$(ls -1 $PATH_CERT/calico-node*)\n" "yellow"

printc "\n# Criando kubeconfig para o CNI plugin\n"
    kubectl config set-cluster $CLUSTER_NAME \
        --certificate-authority=$PATH_CERT/ca.crt \
        --embed-certs=true \
        --server=https://$IP_LB_MASTER:6443 \
        --kubeconfig=$PATH_CONFIG/cni.kubeconfig
    kubectl config set-credentials calico-cni \
        --client-certificate=$PATH_CERT/cni.crt \
        --client-key=$PATH_CERT/cni.key \
        --embed-certs=true \
        --kubeconfig=$PATH_CONFIG/cni.kubeconfig
    kubectl config set-context default \
        --cluster=$CLUSTER_NAME \
        --user=calico-cni \
        --kubeconfig=$PATH_CONFIG/cni.kubeconfig
    kubectl config use-context default --kubeconfig=$PATH_CONFIG/cni.kubeconfig
    printc "$(ls -1 $PATH_CONFIG/cni.kubeconfig)\n" "yellow"

printc "\n# Criando RBAC para o CNI plugin\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/clusterrole-calico-cni.yaml
	kind: ClusterRole
	apiVersion: rbac.authorization.k8s.io/v1
	metadata:
	  name: calico-cni
	rules:
	  # The CNI plugin needs to get pods, nodes, and namespaces.
	  - apiGroups: [""]
	    resources:
	      - pods
	      - nodes
	      - namespaces
	    verbs:
	      - get
	  # The CNI plugin patches pods/status.
	  - apiGroups: [""]
	    resources:
	      - pods/status
	    verbs:
	      - patch
	 # These permissions are required for Calico CNI to perform IPAM allocations.
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      - blockaffinities
	      - ipamblocks
	      - ipamhandles
	    verbs:
	      - get
	      - list
	      - create
	      - update
	      - delete
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      - ipamconfigs
	      - clusterinformations
	      - ippools
	    verbs:
	      - get
	      - list
	EOF
    printc "$(ls -1 $PATH_CONFIG/clusterrole-calico-cni.yaml)\n" "yellow"

    vagrant scp $PATH_CONFIG/clusterrole-calico-cni.yaml master-1:~/
    vagrant ssh master-1 -c "
        kubectl apply -f clusterrole-calico-cni.yaml
        kubectl create clusterrolebinding calico-cni --clusterrole=calico-cni --user=calico-cni
    "

printc "\n# Criando arquivo de configuração para o CNI plugin\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/10-calico.conflist
	{
	  "name": "k8s-pod-network",
	  "cniVersion": "0.3.1",
	  "plugins": [
	    {
	      "type": "calico",
	      "log_level": "info",
	      "datastore_type": "kubernetes",
	      "mtu": 1500,
	      "ipam": {
	          "type": "calico-ipam"
	      },
	      "policy": {
	          "type": "k8s"
	      },
	      "kubernetes": {
	          "kubeconfig": "/etc/cni/net.d/calico-kubeconfig"
	      }
	    },
	    {
	      "type": "portmap",
	      "snat": true,
	      "capabilities": {"portMappings": true}
	    }
	  ]
	}
	EOF
    printc "$(ls -1 $PATH_CONFIG/10-calico.conflist)\n" "yellow"

printc "\n# Instalando CNI plugin\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        for file in \
            $PATH_CONFIG/cni.kubeconfig \
            $PATH_CONFIG/10-calico.conflist; do
            vagrant scp ${file} ${worker}:~/
        done
        vagrant ssh $worker -c "
            wget https://github.com/projectcalico/cni-plugin/releases/download/$CALICO_VERSION/calico-amd64
            wget https://github.com/projectcalico/cni-plugin/releases/download/$CALICO_VERSION/calico-ipam-amd64
            chmod -v 755 calico-amd64
            chmod -v 755 calico-ipam-amd64
            sudo mv -v calico-amd64 /opt/cni/bin/calico
            sudo mv -v calico-ipam-amd64 /opt/cni/bin/calico-ipam
            sudo cp -v cni.kubeconfig /etc/cni/net.d/calico-kubeconfig
            sudo chmod -v 600 /etc/cni/net.d/calico-kubeconfig
            sudo cp -v 10-calico.conflist /etc/cni/net.d/
        "
    done

printc "\n# Instalando Typha\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/clusterrole-calico-typha.yaml
	kind: ClusterRole
	apiVersion: rbac.authorization.k8s.io/v1
	metadata:
	  name: calico-typha
	rules:
	  - apiGroups: [""]
	    resources:
	      - pods
	      - namespaces
	      - serviceaccounts
	      - endpoints
	      - services
	      - nodes
	    verbs:
	      # Used to discover service IPs for advertisement.
	      - watch
	      - list
	  - apiGroups: ["networking.k8s.io"]
	    resources:
	      - networkpolicies
	    verbs:
	      - watch
	      - list
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      - globalfelixconfigs
	      - felixconfigurations
	      - bgppeers
	      - globalbgpconfigs
	      - bgpconfigurations
	      - ippools
	      - ipamblocks
	      - globalnetworkpolicies
	      - globalnetworksets
	      - networkpolicies
	      - clusterinformations
	      - hostendpoints
	      - blockaffinities
	      - networksets
	    verbs:
	      - get
	      - list
	      - watch
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      #- ippools
	      #- felixconfigurations
	      - clusterinformations
	    verbs:
	      - get
	      - create
	      - update
	EOF
    printc "$(ls -1 $PATH_CONFIG/clusterrole-calico-typha.yaml)\n" "yellow"

    cat <<-EOF | sudo tee $PATH_CONFIG/deployment-calico-typha.yaml
	apiVersion: apps/v1
	kind: Deployment
	metadata:
	  name: calico-typha
	  namespace: kube-system
	  labels:
	    k8s-app: calico-typha
	spec:
	  replicas: 2
	  revisionHistoryLimit: 2
	  selector:
	    matchLabels:
	      k8s-app: calico-typha
	  template:
	    metadata:
	      labels:
	        k8s-app: calico-typha
	      annotations:
	        cluster-autoscaler.kubernetes.io/safe-to-evict: 'true'
	    spec:
	      hostNetwork: true
	      tolerations:
	        - key: CriticalAddonsOnly
	          operator: Exists
	      serviceAccountName: calico-typha
	      priorityClassName: system-cluster-critical
	      containers:
	      - image: calico/typha:v3.8.0
	        name: calico-typha
	        ports:
	        - containerPort: 5473
	          name: calico-typha
	          protocol: TCP
	        env:
	          - name: TYPHA_LOGFILEPATH
	            value: "none"
	          - name: TYPHA_LOGSEVERITYSYS
	            value: "none"
	          - name: TYPHA_CONNECTIONREBALANCINGMODE
	            value: "kubernetes"
	          - name: TYPHA_DATASTORETYPE
	            value: "kubernetes"
	          - name: TYPHA_HEALTHENABLED
	            value: "true"
	          - name: TYPHA_CAFILE
	            value: /calico-typha-ca/typhaca.crt
	          - name: TYPHA_CLIENTCN
	            value: calico-node
	          - name: TYPHA_SERVERCERTFILE
	            value: /calico-typha-certs/typha.crt
	          - name: TYPHA_SERVERKEYFILE
	            value: /calico-typha-certs/typha.key
	        livenessProbe:
	          httpGet:
	            path: /liveness
	            port: 9098
	            host: localhost
	          periodSeconds: 30
	          initialDelaySeconds: 30
	        readinessProbe:
	          httpGet:
	            path: /readiness
	            port: 9098
	            host: localhost
	          periodSeconds: 10
	        volumeMounts:
	        - name: calico-typha-ca
	          mountPath: "/calico-typha-ca"
	          readOnly: true
	        - name: calico-typha-certs
	          mountPath: "/calico-typha-certs"
	          readOnly: true
	      volumes:
	      - name: calico-typha-ca
	        configMap:
	          name: calico-typha-ca
	      - name: calico-typha-certs
	        secret:
	          secretName: calico-typha-certs
	EOF
    printc "$(ls -1 $PATH_CONFIG/deployment-calico-typha.yaml)\n" "yellow"

    cat <<-EOF | sudo tee $PATH_CONFIG/service-calico-typha.yaml
	apiVersion: v1
	kind: Service
	metadata:
	  name: calico-typha
	  namespace: kube-system
	  labels:
	    k8s-app: calico-typha
	spec:
	  ports:
	    - port: 5473
	      protocol: TCP
	      targetPort: calico-typha
	      name: calico-typha
	  selector:
	    k8s-app: calico-typha
	EOF
    printc "$(ls -1 $PATH_CONFIG/service-calico-typha.yaml)\n" "yellow"

    for file in \
        $PATH_CERT/typhaca.crt \
        $PATH_CERT/typha.key \
        $PATH_CERT/typha.crt \
        $PATH_CONFIG/clusterrole-calico-typha.yaml \
        $PATH_CONFIG/deployment-calico-typha.yaml \
        $PATH_CONFIG/service-calico-typha.yaml; do
        vagrant scp ${file} master-1:~/
    done
    vagrant ssh master-1 -c "
        kubectl create configmap -n kube-system calico-typha-ca --from-file=typhaca.crt
        kubectl create secret generic -n kube-system calico-typha-certs --from-file=typha.key --from-file=typha.crt
        kubectl create serviceaccount -n kube-system calico-typha
        kubectl apply -f clusterrole-calico-typha.yaml
        kubectl create clusterrolebinding calico-typha --clusterrole=calico-typha --serviceaccount=kube-system:calico-typha
        kubectl apply -f deployment-calico-typha.yaml
        kubectl apply -f service-calico-typha.yaml
    "

printc "\n# Instalando calico node\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/clusterrole-calico-node.yaml
	kind: ClusterRole
	apiVersion: rbac.authorization.k8s.io/v1
	metadata:
	  name: calico-node
	rules:
	  - apiGroups: [""]
	    resources:
	      - pods
	      - nodes
	      - namespaces
	    verbs:
	      - get
	  - apiGroups: ["discovery.k8s.io"]
	    resources:
	      - endpointslices
	    verbs:
	      - watch
	      - list
	  - apiGroups: [""]
	    resources:
	      - endpoints
	      - services
	    verbs:
	      - watch
	      - list
	      - get
	  - apiGroups: [""]
	    resources:
	      - configmaps
	    verbs:
	      - get
	  - apiGroups: [""]
	    resources:
	      - nodes/status
	    verbs:
	      # Needed for clearing NodeNetworkUnavailable flag.
	      - patch
	      # Calico stores some configuration information in node annotations.
	      - update
	  - apiGroups: ["networking.k8s.io"]
	    resources:
	      - networkpolicies
	    verbs:
	      - watch
	      - list
	  - apiGroups: [""]
	    resources:
	      - pods
	      - namespaces
	      - serviceaccounts
	    verbs:
	      - list
	      - watch
	  - apiGroups: [""]
	    resources:
	      - pods/status
	    verbs:
	      - patch
	  - apiGroups: [""]
	    resources:
	      - serviceaccounts/token
	    resourceNames:
	      - calico-node
	    verbs:
	      - create
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      - globalfelixconfigs
	      - felixconfigurations
	      - bgppeers
	      - globalbgpconfigs
	      - bgpconfigurations
	      - ippools
	      - ipamblocks
	      - globalnetworkpolicies
	      - globalnetworksets
	      - networkpolicies
	      - networksets
	      - clusterinformations
	      - hostendpoints
	      - blockaffinities
	    verbs:
	      - get
	      - list
	      - watch
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      - ippools
	      - felixconfigurations
	      - clusterinformations
	    verbs:
	      - create
	      - update
	  - apiGroups: [""]
	    resources:
	      - nodes
	    verbs:
	      - get
	      - list
	      - watch
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      - blockaffinities
	      - ipamblocks
	      - ipamhandles
	    verbs:
	      - get
	      - list
	      - create
	      - update
	      - delete
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      - ipamconfigs
	    verbs:
	      - get
	  - apiGroups: ["crd.projectcalico.org"]
	    resources:
	      - blockaffinities
	    verbs:
	      - watch
	EOF
    printc "$(ls -1 $PATH_CONFIG/clusterrole-calico-node.yaml)\n" "yellow"

	cat <<-EOF | sudo tee $PATH_CONFIG/daemonset-calico-node.yaml
	kind: DaemonSet
	apiVersion: apps/v1
	metadata:
	  name: calico-node
	  namespace: kube-system
	  labels:
	    k8s-app: calico-node
	spec:
	  selector:
	    matchLabels:
	      k8s-app: calico-node
	  updateStrategy:
	    type: RollingUpdate
	    rollingUpdate:
	      maxUnavailable: 1
	  template:
	    metadata:
	      labels:
	        k8s-app: calico-node
	    spec:
	      nodeSelector:
	        kubernetes.io/os: linux
	      hostNetwork: true
	      tolerations:
	        - effect: NoSchedule
	          operator: Exists
	        - key: CriticalAddonsOnly
	          operator: Exists
	        - effect: NoExecute
	          operator: Exists
	      serviceAccountName: calico-node
	      terminationGracePeriodSeconds: 0
	      priorityClassName: system-node-critical
	      containers:
	        - name: calico-node
	          image: calico/node:v3.20.0
	          env:
	            - name: DATASTORE_TYPE
	              value: "kubernetes"
	            - name: FELIX_TYPHAK8SSERVICENAME
	              value: calico-typha
	            - name: WAIT_FOR_DATASTORE
	              value: "true"
	            - name: NODENAME
	              valueFrom:
	                fieldRef:
	                  fieldPath: spec.nodeName
	            - name: CALICO_NETWORKING_BACKEND
	              value: bird
	            - name: CLUSTER_TYPE
	              value: "k8s,bgp"
	            - name: IP
	              value: "autodetect"
	            - name: CALICO_DISABLE_FILE_LOGGING
	              value: "true"
	            - name: FELIX_DEFAULTENDPOINTTOHOSTACTION
	              value: "ACCEPT"
	            - name: FELIX_IPV6SUPPORT
	              value: "false"
	            - name: FELIX_LOGSEVERITYSCREEN
	              value: "info"
	            - name: FELIX_HEALTHENABLED
	              value: "true"
	            - name: FELIX_TYPHACAFILE
	              value: /calico-typha-ca/typhaca.crt
	            - name: FELIX_TYPHACN
	              value: calico-typha
	            - name: FELIX_TYPHACERTFILE
	              value: /calico-node-certs/calico-node.crt
	            - name: FELIX_TYPHAKEYFILE
	              value: /calico-node-certs/calico-node.key
	          securityContext:
	            privileged: true
	          resources:
	            requests:
	              cpu: 250m
	          lifecycle:
	            preStop:
	              exec:
	                command:
	                - /bin/calico-node
	                - -shutdown
	          livenessProbe:
	            httpGet:
	              path: /liveness
	              port: 9099
	              host: localhost
	            periodSeconds: 10
	            initialDelaySeconds: 10
	            failureThreshold: 6
	          readinessProbe:
	            exec:
	              command:
	              - /bin/calico-node
	              - -bird-ready
	              - -felix-ready
	            periodSeconds: 10
	          volumeMounts:
	            - mountPath: /lib/modules
	              name: lib-modules
	              readOnly: true
	            - mountPath: /run/xtables.lock
	              name: xtables-lock
	              readOnly: false
	            - mountPath: /var/run/calico
	              name: var-run-calico
	              readOnly: false
	            - mountPath: /var/lib/calico
	              name: var-lib-calico
	              readOnly: false
	            - mountPath: /var/run/nodeagent
	              name: policysync
	            - mountPath: "/calico-typha-ca"
	              name: calico-typha-ca
	              readOnly: true
	            - mountPath: /calico-node-certs
	              name: calico-node-certs
	              readOnly: true
	      volumes:
	        - name: lib-modules
	          hostPath:
	            path: /lib/modules
	        - name: var-run-calico
	          hostPath:
	            path: /var/run/calico
	        - name: var-lib-calico
	          hostPath:
	            path: /var/lib/calico
	        - name: xtables-lock
	          hostPath:
	            path: /run/xtables.lock
	            type: FileOrCreate
	        - name: policysync
	          hostPath:
	            type: DirectoryOrCreate
	            path: /var/run/nodeagent
	        - name: calico-typha-ca
	          configMap:
	            name: calico-typha-ca
	        - name: calico-node-certs
	          secret:
	            secretName: calico-node-certs
	EOF
    printc "$(ls -1 $PATH_CONFIG/daemonset-calico-node.yaml)\n" "yellow"

    for file in \
        $PATH_CERT/calico-node.key \
        $PATH_CERT/calico-node.crt \
        $PATH_CONFIG/clusterrole-calico-node.yaml \
        $PATH_CONFIG/daemonset-calico-node.yaml; do
        vagrant scp ${file} master-1:~/
    done
    vagrant ssh master-1 -c "
        kubectl create secret generic -n kube-system calico-node-certs --from-file=calico-node.key --from-file=calico-node.crt
        kubectl create serviceaccount -n kube-system calico-node
        kubectl apply -f clusterrole-calico-node.yaml
        kubectl create clusterrolebinding calico-node --clusterrole=calico-node --serviceaccount=kube-system:calico-node
        kubectl apply -f daemonset-calico-node.yaml
    "

printc "\n# Configurando BGP peering\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/peer-to-rrs.yaml
	kind: BGPPeer
	apiVersion: projectcalico.org/v3
	metadata:
	  name: peer-to-rrs
	spec:
	  nodeSelector: "!has(calico-route-reflector)"
	  peerSelector: has(calico-route-reflector)
	EOF
    printc "$(ls -1 $PATH_CONFIG/peer-to-rrs.yaml)\n" "yellow"

    cat <<-EOF | sudo tee $PATH_CONFIG/rrs-to-rrs.yaml
	kind: BGPPeer
	apiVersion: projectcalico.org/v3
	metadata:
	  name: rrs-to-rrs
	spec:
	  nodeSelector: has(calico-route-reflector)
	  peerSelector: has(calico-route-reflector)
	EOF
    printc "$(ls -1 $PATH_CONFIG/rrs-to-rrs.yaml)\n" "yellow"

    cat <<-EOF | sudo tee $PATH_CONFIG/bgpconfiguration-default.yaml
	apiVersion: projectcalico.org/v3
	kind: BGPConfiguration
	metadata:
	  name: default
	spec:
	  nodeToNodeMeshEnabled: false
	  asNumber: 64512
	EOF
    printc "$(ls -1 $PATH_CONFIG/bgpconfiguration-default.yaml)\n" "yellow"

    for file in \
        $PATH_CONFIG/peer-to-rrs.yaml \
        $PATH_CONFIG/rrs-to-rrs.yaml \
        $PATH_CONFIG/bgpconfiguration-default.yaml; do
        vagrant scp ${file} master-1:~/
    done
    vagrant ssh master-1 -c "
        kubectl patch node worker-1 -p '{\"spec\":{\"bgp\":{\"routeReflectorClusterID\":\"224.0.0.1\"}}}'
        kubectl patch node worker-2 -p '{\"spec\":{\"bgp\":{\"routeReflectorClusterID\":\"224.0.0.1\"}}}'
        kubectl patch node worker-1 -p '{\"metadata\":{\"labels\":{\"calico-route-reflector\":\"\"}}}'
        kubectl patch node worker-2 -p '{\"metadata\":{\"labels\":{\"calico-route-reflector\":\"\"}}}'
        calicoctl apply -f peer-to-rrs.yaml
        calicoctl apply -f rrs-to-rrs.yaml
        calicoctl apply -f bgpconfiguration-default.yaml
    "

printc "\n# Validando os nodes\n"
    vagrant ssh master-1 -c "
        sleep 10
        kubectl get nodes
    "
