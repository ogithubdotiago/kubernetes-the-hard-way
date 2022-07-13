#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n########################################\n"
printc "# Configurando Pod Network - Weave Net #\n"
printc "########################################\n"

printc "\n# Instalando Weave Net $WEAVE_VERSION\n"
    vagrant ssh master-1 -c " 
        kubectl apply -f https://cloud.weave.works/k8s/net?k8s-version=$K8S_VERSION
        kubectl wait --namespace kube-system --for=condition=ready pod -l name=weave-net --timeout=60s
    "

printc "\n# Validando instalando Weave Net\n"
    vagrant ssh master-1 -c "
        kubectl get nodes
    "
