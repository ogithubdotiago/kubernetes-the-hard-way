#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n###########################\n"
printc "# Configurando CNI Plugin #\n"
printc "###########################\n"

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
