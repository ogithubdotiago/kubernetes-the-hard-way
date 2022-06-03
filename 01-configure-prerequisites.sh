#!/bin/bash

source $(dirname $0)/00-include.sh

print_steps "\n#Rodar vagrant <cmd> sem estar no path\n"
    echo export VAGRANT_CWD="$(pwd)/vagrant/"

print_steps "\n#Visualizando dhcp virtualbox\n"
    VBoxManage list dhcpservers |egrep 'LowerIPAddress|UpperIPAddress|NetworkMask'

print_steps "\n#Instalando plugin vagrant scp\n"
    vagrant plugin install vagrant-scp
