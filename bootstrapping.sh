#!/bin/bash

source $(dirname $0)/00-include.sh

#default
source 02-create-certificate-authority.sh ; sleep 5
source 03-create-configuration-files.sh ; sleep 5
source 04-create-data-encryption-keys.sh ; sleep 5
source 05-bootstrapping-etcd.sh ; sleep 5
source 06-bootstrapping-controlplane.sh ; sleep 5
source 07-bootstrapping-loadbalancer.sh ; sleep 5
source 08-bootstrapping-container-runtime.sh ; sleep 5
source 09-bootstrapping-nodes.sh ; sleep 5
source 10-bootstrapping-pod-networking.sh ; sleep 5
source 11-configure-apiserver-to-kubelet.sh ; sleep 5
source 12-bootstrapping-dns.sh; sleep 5

#addons
source 13-bootstrapping-gangway-dex-ldap.sh; sleep 5