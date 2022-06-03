#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n############################\n"
printc "# Configurando Pod Network #\n"
printc "############################\n"

printc "\n# Download CNI Plugin $CNI_VERSION\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            wget -q --show-progress --https-only --timestamping \
            https://github.com/containernetworking/plugins/releases/download/$CNI_VERSION/cni-plugins-linux-amd64-$CNI_VERSION.tgz
        "
    done

printc "\n# Criando diretorio CNI Plugin\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            sudo mkdir -v -p \
            /etc/cni/net.d \
            /opt/cni/bin \
        "
    done

printc "\n# Instalando CNI Plugin\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            sudo tar -xzvf cni-plugins-linux-amd64-$CNI_VERSION.tgz --directory /opt/cni/bin/
        " 
    done

printc "\n# Instalando Weave Net $WEAVE_VERSION\n"
    vagrant ssh master-1 -c " 
        kubectl apply -f https://cloud.weave.works/k8s/net?k8s-version=$K8S_VERSION
        kubectl wait --namespace kube-system --for=condition=ready pod -l name=weave-net --timeout=60s
    "

printc "\n# Validando instalando Weave Net\n"
    vagrant ssh master-1 -c "
        kubectl get nodes
    "
