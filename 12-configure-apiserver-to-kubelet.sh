#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n####################################\n"
printc "# RBAC para autorizacao ao kubelet #\n"
printc "####################################\n"

printc "\n# Criando ClusterRole\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/clusterrole-kube-apiserver-to-kubelet.yaml
	apiVersion: rbac.authorization.k8s.io/v1
	kind: ClusterRole
	metadata:
	  annotations:
	    rbac.authorization.kubernetes.io/autoupdate: "true"
	  labels:
	    kubernetes.io/bootstrapping: rbac-defaults
	  name: system:kube-apiserver-to-kubelet
	rules:
	  - apiGroups:
	      - ""
	    resources:
	      - nodes/proxy
	      - nodes/stats
	      - nodes/log
	      - nodes/spec
	      - nodes/metrics
	    verbs:
	      - "*"
	EOF
    printc "$(ls -1 $PATH_CONFIG/clusterrole-kube-apiserver-to-kubelet.yaml)\n" "yellow"

printc "\n# Criando ClusterRoleBinding\n"
	cat <<-EOF | sudo tee $PATH_CONFIG/clusterrolebinding-kube-apiserver-to-kubelet.yaml
	apiVersion: rbac.authorization.k8s.io/v1
	kind: ClusterRoleBinding
	metadata:
	  name: system:kube-apiserver
	  namespace: ""
	roleRef:
	  apiGroup: rbac.authorization.k8s.io
	  kind: ClusterRole
	  name: system:kube-apiserver-to-kubelet
	subjects:
	  - apiGroup: rbac.authorization.k8s.io
	    kind: User
	    name: kube-apiserver
	EOF
    printc "$(ls -1 $PATH_CONFIG/clusterrolebinding-kube-apiserver-to-kubelet.yaml)\n" "yellow"

printc "\n# Aplicando Roles\n"
    for file in \
        $PATH_CONFIG/clusterrole-kube-apiserver-to-kubelet.yaml \
        $PATH_CONFIG/clusterrolebinding-kube-apiserver-to-kubelet.yaml; do
        vagrant scp ${file} master-1:~/
    done
    vagrant ssh master-1 -c "
        kubectl apply -f clusterrole-kube-apiserver-to-kubelet.yaml
        kubectl apply -f clusterrolebinding-kube-apiserver-to-kubelet.yaml
    "
