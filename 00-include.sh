#!/bin/bash

#cluster_info
CLUSTER_NAME="kubernetes-jilo"
CERT_DAYS="3650"

#network
NET_CIDR="192.168.56"
NET_CIDR_SVC="10.96.0.0/24"
NET_CIDR_POD="10.32.0.0/12"
IP_SVC_K8S="10.96.0.1"
IP_SVC_DNS="10.96.0.10"
IP_LB_MASTER="192.168.56.30"
IP_LB_WORKER="192.168.56.40"

#path
PATH_VAGRANT="vagrant"
PATH_CONFIG="config"
PATH_CERT="certificate"

#version_control
K8S_VERSION="v1.20.8"
ETCD_VERSION="v3.5.0"
COREDNS_VERSION="1.9.3"
CONTAINERD_VERSION="1.5.10"
CNI_VERSION="v1.1.1"
CRICTL_VERSION="v1.21.0"
HAPROXY_VERSION="2.4.14"
HELM_VERSION="v3.9.0"
KUBECTX_VERSION="v0.9.4"
KUBENS_VERSION="v0.9.4"
CALICO_VERSION="v3.20.0"
OPENLDAP_VERSION="1.5.0"
DEX_VERSION="v2.30.0"
GANGWAY_VERSION="v3.0.0"

#custom_print
printc() {
    if [ "$2" == "yellow" ]; then
        COLOR="93m" #yellow
    else
        COLOR="92m" #green
    fi
    STARTCOLOR="\e[$COLOR"
    ENDCOLOR="\e[0m"
    printf "$STARTCOLOR%b$ENDCOLOR" "$1"
}
