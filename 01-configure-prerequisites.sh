#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n#Rodar vagrant <cmd> sem estar no path\n"
    echo export VAGRANT_CWD="$(pwd)/vagrant/"

printc "\n#Visualizando dhcp virtualbox\n"
    VBoxManage list dhcpservers |egrep 'LowerIPAddress|UpperIPAddress|NetworkMask'

printc "\n#Instalando plugin vagrant scp\n"
    vagrant plugin install vagrant-scp
