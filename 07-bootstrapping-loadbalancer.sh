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
frontend kubernetes
    bind $LB_ADDRESS:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 $NET_CIDR.11:6443 check fall 3 rise 2
    server master-2 $NET_CIDR.12:6443 check fall 3 rise 2
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
