#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n# Execute este comando para rodar o vagrant sem estar no path\n"
    echo export VAGRANT_CWD="$(pwd)/vagrant/"

printc "\n# Visualizando dhcp virtualbox\n"
printc "Rede definida neste lab: $NET_CIDR\n" "yellow"
    VBoxManage list dhcpservers |egrep 'LowerIPAddress|UpperIPAddress|NetworkMask'

printc "\n# Instalando plugin vagrant scp\n"
    validate=$(vagrant plugin list |grep scp ; echo $?)
    if [[ $validate == "1" ]] ; then
        vagrant plugin install vagrant-scp
    else
        vagrant plugin list |grep scp
    fi

