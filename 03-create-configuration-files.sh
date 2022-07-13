#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n#########################################################\n"
printc "# Gerando .kubeconfig para autenticacao do controlplane #\n"
printc "#########################################################\n"

printc "\n# Criando .kubeconfig kube-controller-manager\n"
    kubectl config set-cluster $CLUSTER_NAME \
        --certificate-authority=$PATH_CERT/ca.crt \
        --embed-certs=true \
        --server=https://127.0.0.1:6443 \
        --kubeconfig=$PATH_CONFIG/kube-controller-manager.kubeconfig
    kubectl config set-credentials system:kube-controller-manager \
        --client-certificate=$PATH_CERT/kube-controller-manager.crt \
        --client-key=$PATH_CERT/kube-controller-manager.key \
        --embed-certs=true \
        --kubeconfig=$PATH_CONFIG/kube-controller-manager.kubeconfig
    kubectl config set-context default \
        --cluster=$CLUSTER_NAME \
        --user=system:kube-controller-manager \
        --kubeconfig=$PATH_CONFIG/kube-controller-manager.kubeconfig
    kubectl config use-context default --kubeconfig=$PATH_CONFIG/kube-controller-manager.kubeconfig
printc "$(ls -1 $PATH_CONFIG/kube-controller-manager.kubeconfig)\n" "yellow"

printc "\n# Criando .kubeconfig kube-scheduler\n"
    kubectl config set-cluster $CLUSTER_NAME \
        --certificate-authority=$PATH_CERT/ca.crt \
        --embed-certs=true \
        --server=https://127.0.0.1:6443 \
        --kubeconfig=$PATH_CONFIG/kube-scheduler.kubeconfig
    kubectl config set-credentials system:kube-scheduler \
        --client-certificate=$PATH_CERT/kube-scheduler.crt \
        --client-key=$PATH_CERT/kube-scheduler.key \
        --embed-certs=true \
        --kubeconfig=$PATH_CONFIG/kube-scheduler.kubeconfig
    kubectl config set-context default \
        --cluster=$CLUSTER_NAME \
        --user=system:kube-scheduler \
        --kubeconfig=$PATH_CONFIG/kube-scheduler.kubeconfig
    kubectl config use-context default --kubeconfig=$PATH_CONFIG/kube-scheduler.kubeconfig
printc "$(ls -1 $PATH_CONFIG/kube-scheduler.kubeconfig)\n" "yellow"

printc "\n# Criando .kubeconfig admin\n"
    kubectl config set-cluster $CLUSTER_NAME \
        --certificate-authority=$PATH_CERT/ca.crt \
        --embed-certs=true \
        --server=https://$IP_LB_MASTER:6443 \
        --kubeconfig=$PATH_CONFIG/admin.kubeconfig
    kubectl config set-credentials admin \
        --client-certificate=$PATH_CERT/admin.crt \
        --client-key=$PATH_CERT/admin.key \
        --embed-certs=true \
        --kubeconfig=$PATH_CONFIG/admin.kubeconfig
    kubectl config set-context default \
        --cluster=$CLUSTER_NAME \
        --user=admin \
        --kubeconfig=$PATH_CONFIG/admin.kubeconfig \
        --namespace=kube-system
    kubectl config use-context default --kubeconfig=$PATH_CONFIG/admin.kubeconfig
printc "$(ls -1 $PATH_CONFIG/admin.kubeconfig)\n" "yellow"
