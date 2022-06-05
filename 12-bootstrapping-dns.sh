#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n########################\n"
printc "# Configurando CoreDNS #\n"
printc "########################\n"

printc "\n# Download Helm $HELM_VERSION\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c " 
            wget -q --show-progress --https-only --timestamping \
            https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz
        "
    done

printc "\n# Instalando Helm\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c "
            sudo tar -zxvf helm-$HELM_VERSION-linux-amd64.tar.gz
            sudo mv -v linux-amd64/helm /usr/local/bin/
        "
    done

printc "\n# Instalando CoreDNS $COREDNS_VERSION\n"
    vagrant ssh master-1 -c "
        helm repo add coredns https://coredns.github.io/helm
        helm --namespace=kube-system install coredns \
        coredns/coredns \
        --set image.tag=$COREDNS_VERSION \
        --set service.clusterIP=$IP_SVC_COREDNS \
        --set replicaCount=2 \
        --set serviceAccount.create=true
    "

printc "\n# Validando instalação CoreDNS\n"
    vagrant ssh master-1 -c "
        kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml
        kubectl wait --for=condition=ready pod/dnsutils -n default --timeout=120s
        kubectl exec -i -t dnsutils -n default -- nslookup kubernetes.default
        kubectl delete pod dnsutils -n default
    "
