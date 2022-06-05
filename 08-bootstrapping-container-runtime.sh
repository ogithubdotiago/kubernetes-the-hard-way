#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n#############################################\n"
printc "# Configurando Container Runtime containerd #\n"
printc "#############################################\n"

printc "\n# Instalacao containerd $CONTAINERD_VERSION\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
            echo 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable' | sudo tee /etc/apt/sources.list.d/docker.list
            sudo apt update
            sudo apt install -y containerd.io=$CONTAINERD_VERSION*
        "
    done

printc "\n# Configurando containerd\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            sudo mkdir -v -p /etc/containerd/
            sudo containerd config default > /etc/containerd/config.toml
        "
    done

cat << EOF | sudo tee $PATH_CONFIG/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
EOF
printc "$(ls -1 $PATH_CONFIG/config.toml)\n" "yellow"

cat <<EOF | sudo tee $PATH_CONFIG/containerd.conf
overlay
br_netfilter
EOF
printc "$(ls -1 $PATH_CONFIG/containerd.conf)\n" "yellow"

cat <<EOF | sudo tee $PATH_CONFIG/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
printc "$(ls -1 $PATH_CONFIG/99-kubernetes-cri.conf)\n" "yellow"

cat <<EOF | sudo tee $PATH_CONFIG/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF
printc "$(ls -1 $PATH_CONFIG/crictl.yaml)\n" "yellow"

    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        for file in \
            $PATH_CONFIG/config.toml \
            $PATH_CONFIG/containerd.conf \
            $PATH_CONFIG/99-kubernetes-cri.conf \
            $PATH_CONFIG/crictl.yaml; do
            vagrant scp ${file} ${worker}:~/
        done
        vagrant ssh $worker -c "
            sudo mv -v config.toml /etc/containerd/config.toml
            sudo mv -v containerd.conf /etc/modules-load.d/containerd.conf
            sudo mv -v 99-kubernetes-cri.conf /etc/sysctl.d/99-kubernetes-cri.conf
            sudo mv -v crictl.yaml /etc/crictl.yaml
            sudo modprobe overlay
            sudo modprobe br_netfilter
            sudo sysctl --system
        "
    done

printc "\n# Configurando crictl\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c "
            wget -q --show-progress --https-only --timestamping \
            https://github.com/kubernetes-sigs/cri-tools/releases/download/$K8S_VERSION/crictl-$K8S_VERSION-linux-amd64.tar.gz
            sudo tar -xvf crictl-$K8S_VERSION-linux-amd64.tar.gz
            sudo chmod +x crictl
            sudo mv -v crictl /usr/local/bin/
            sudo systemctl restart containerd
        "
    done
