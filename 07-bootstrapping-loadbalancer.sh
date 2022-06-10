#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n######################################\n"
printc "# Configurando Load Balancer HAProxy #\n"
printc "######################################\n"

printc "\n# Download HAProxy $HAPROXY_VERSION\n"
    vagrant ssh loadbalancer -c "
        sudo apt-get -y update \
        && sudo apt-get install -q -y haproxy=$HAPROXY_VERSION*
    "

printc "\n# Configurando HAProxy $HAPROXY_VERSION\n"

cat <<EOF | sudo tee $PATH_CONFIG/haproxy.cfg 
frontend kube-apiserver
    bind $IP_LB_MASTER:6443
    option tcplog
    mode tcp
    default_backend kube-apiserver

frontend dex
    bind $IP_LB_WORKER:32000
    option tcplog
    mode tcp
    default_backend dex

frontend gangway
    bind $IP_LB_WORKER:32001
    option tcplog
    mode tcp
    default_backend gangway

backend kube-apiserver
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 $NET_CIDR.11:6443 check fall 3 rise 2
    server master-2 $NET_CIDR.12:6443 check fall 3 rise 2

backend dex
    mode tcp
    balance roundrobin
    option tcp-check
    server worker-1 $NET_CIDR.21:32000 check fall 3 rise 2
    server worker-2 $NET_CIDR.22:32000 check fall 3 rise 2

backend gangway
    mode tcp
    balance roundrobin
    option tcp-check
    server worker-1 $NET_CIDR.21:32001 check fall 3 rise 2
    server worker-2 $NET_CIDR.22:32001 check fall 3 rise 2
EOF

    vagrant scp $PATH_CONFIG/haproxy.cfg loadbalancer:~/
    vagrant ssh loadbalancer -c "
        sudo mv -v haproxy.cfg /etc/haproxy/haproxy.cfg
        sudo systemctl daemon-reload
        sudo systemctl enable haproxy
        sudo systemctl restart haproxy
    "

printc "\n# Validando HAProxy\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c "
            curl  https://$NET_CIDR.30:6443/version -k
        "
    done
