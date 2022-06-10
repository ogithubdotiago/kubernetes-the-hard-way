#!/bin/bash

#cluster_info
CLUSTER_NAME="kubernetes-jilo"
CERT_DAYS="3650"

#network
NET_CIDR="192.168.56"
NET_CIDR_SVC="10.96.0.0/24"
IP_SVC_K8S="10.96.0.1"
IP_SVC_DNS="10.96.0.10"
IP_LB_MASTER="192.168.56.30"
IP_LB_WORKER="192.168.56.40"

#path
PATH_TEMP="temp"
PATH_CONFIG="config"
PATH_CERT="certificate"

#version_control
K8S_VERSION="v1.20.0"
ETCD_VERSION="v3.5.0"
COREDNS_VERSION="1.9.3"
CONTAINERD_VERSION="1.5.10"
CNI_VERSION="v1.1.1"
HAPROXY_VERSION="2.4.14"
HELM_VERSION="v3.9.0"
KUBECTX_VERSION="v0.9.4"
KUBENS_VERSION="v0.9.4"

#addons
PATH_LDAP="addons/ldap"
PATH_DEX="addons/dex"
PATH_GANGWAY="addons/gangway"

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
