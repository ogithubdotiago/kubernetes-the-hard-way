#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n#############################################\n"
printc "# Configurando Container Runtime containerd #\n"
printc "#############################################\n"

printc "\n# Instalando/Configurando dependencias do sistema operacional\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            sudo apt-get -y update
            sudo apt-get -q -y install socat conntrack ipset
            sudo swapoff -a
        "
    done

printc "\n# Download binarios containerd $CONTAINERD_VERSION\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            wget -q --show-progress --https-only --timestamping \
            https://github.com/kubernetes-sigs/cri-tools/releases/download/$K8S_VERSION/crictl-$K8S_VERSION-linux-amd64.tar.gz \
            https://github.com/opencontainers/runc/releases/download/$RUNC_VERSION/runc.amd64 \
            https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz \
        "
    done

printc "\n# Criando diretorio containerd\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            sudo mkdir -v /etc/containerd/ \
        "
    done

printc "\n# Configurando containerd\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c "
            sudo tar -xvf crictl-$K8S_VERSION-linux-amd64.tar.gz
            sudo tar -xvf containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz -C containerd
            sudo mv -v runc.amd64 runc
            chmod +x crictl runc 
            sudo mv -v crictl runc /usr/local/bin/
            sudo mv -v containerd/bin/* /bin/
        "
    done

cat << EOF | sudo tee $PATH_CONFIG/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        for file in $PATH_CONFIG/config.toml; do
            vagrant scp ${file} ${worker}:~/
        done
        vagrant ssh $worker -c "
            sudo mv -v config.toml /etc/containerd/
        "
    done

cat <<EOF | sudo tee $PATH_CONFIG/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        for file in $PATH_CONFIG/containerd.service; do
            vagrant scp ${file} ${worker}:~/
        done
        vagrant ssh $worker -c "
            sudo mv -v containerd.service /etc/systemd/system/
        "
        vagrant ssh $worker -c "
            sudo systemctl daemon-reload
            sudo systemctl enable containerd
            sudo systemctl start containerd
        "
    done
