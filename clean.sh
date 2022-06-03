#!/bin/bash

source $(dirname $0)/00-include.sh

rm -f $PATH_CERT/*.crt
rm -f $PATH_CERT/*.key
rm -f $PATH_CERT/*.csr
rm -f $PATH_CERT/*.cnf
rm -f $PATH_CONFIG/*.kubeconfig
rm -f $PATH_CONFIG/*.yaml
rm -f $PATH_CONFIG/*.service
rm -f $PATH_CONFIG/*.toml
rm -f $PATH_CONFIG/*.cfg
