#!/bin/bash

#cluster_info
CLUSTER_NAME="kubernetes-jilo"
CERT_DAYS="3650"

#network
NET_CIDR="192.168.56"
LB_ADDRESS="192.168.56.30"

#path
PATH_TEMP="temp"
PATH_CONFIG="config"
PATH_CERT="certificate"

#version_control
K8S_VERSION="v1.20.0"
ETCD_VERSION="v3.5.0"
COREDNS_VERSION="v1.9.3"
CONTAINERD_VERSION="1.5.10"
CNI_VERSION="v1.1.1"
RUNC_VERSION="v1.1.2"
HAPROXY_VERSION="2.4.14"
HELM_VERSION="3.5.0"

#custom_print
printc () {
    if [ "$2" == "yellow" ] ; then
        COLOR="93m"; #yellow
    else 
        COLOR="92m"; #green
    fi
    STARTCOLOR="\e[$COLOR";
    ENDCOLOR="\e[0m";
    printf "$STARTCOLOR%b$ENDCOLOR" "$1";
}