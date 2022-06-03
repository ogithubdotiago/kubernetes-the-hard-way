#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n#############################\n"
printc "# Configurando Worker Nodes #\n"
printc "#############################\n"

printc "\n# Criando certificado para o kubelet\n"
    for worker in worker-{1..2}; do
    printc "\n$worker\n" "yellow"
    [ $worker == worker-1 ] && ip="21" || ip="22"

cat > $PATH_CERT/openssl-$worker.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $worker
IP.1 = $NET_CIDR.$ip
EOF

    openssl genrsa -out $PATH_CERT/$worker.key 2048
    openssl req -new -key $PATH_CERT/$worker.key -subj "/CN=system:node:$worker/O=system:nodes" \
        -out $PATH_CERT/$worker.csr -config $PATH_CERT/openssl-$worker.cnf
    openssl x509 -req -in $PATH_CERT/$worker.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial \
        -out $PATH_CERT/$worker.crt -extensions v3_req -extfile $PATH_CERT/openssl-$worker.cnf -days $CERT_DAYS
    done

printc "\n# Criando certificado kube-proxy\n"
    openssl genrsa -out $PATH_CERT/kube-proxy.key 2048
    openssl req -new -key $PATH_CERT/kube-proxy.key -subj "/CN=system:kube-proxy" \
        -out $PATH_CERT/kube-proxy.csr
    openssl x509 -req -in $PATH_CERT/kube-proxy.csr -CA $PATH_CERT/ca.crt -CAkey $PATH_CERT/ca.key -CAcreateserial \
        -out $PATH_CERT/kube-proxy.crt -days $CERT_DAYS

printc "\n# Criando kubelet .kubeconfig\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        kubectl config set-cluster $CLUSTER_NAME \
            --certificate-authority=$PATH_CERT/ca.crt \
            --embed-certs=true \
            --server=https://${LB_ADDRESS}:6443 \
            --kubeconfig=$PATH_CONFIG/$worker.kubeconfig
        kubectl config set-credentials system:node:$worker \
            --client-certificate=$PATH_CERT/$worker.crt \
            --client-key=$PATH_CERT/$worker.key \
            --embed-certs=true \
            --kubeconfig=$PATH_CONFIG/$worker.kubeconfig
        kubectl config set-context default \
            --cluster=$CLUSTER_NAME \
            --user=system:node:$worker \
            --kubeconfig=$PATH_CONFIG/$worker.kubeconfig
        kubectl config use-context default --kubeconfig=$PATH_CONFIG/$worker.kubeconfig
    done

printc "\n# Criando kube-proxy .kubeconfig\n"
    kubectl config set-cluster $CLUSTER_NAME \
        --certificate-authority=$PATH_CERT/ca.crt \
        --embed-certs=true \
        --server=https://${LB_ADDRESS}:6443 \
        --kubeconfig=$PATH_CONFIG/kube-proxy.kubeconfig
    kubectl config set-credentials system:kube-proxy \
        --client-certificate=$PATH_CERT/kube-proxy.crt \
        --client-key=$PATH_CERT/kube-proxy.key \
        --embed-certs=true \
        --kubeconfig=$PATH_CONFIG/kube-proxy.kubeconfig
    kubectl config set-context default \
        --cluster=$CLUSTER_NAME \
        --user=system:kube-proxy \
        --kubeconfig=$PATH_CONFIG/kube-proxy.kubeconfig
    kubectl config use-context default --kubeconfig=$PATH_CONFIG/kube-proxy.kubeconfig

printc "\n# Criando kubelet-config.yaml\n"
    for worker in worker-{1..2}; do
    printc "\n$worker\n" "yellow"
cat <<EOF | sudo tee $PATH_CONFIG/kubelet-config-$worker.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.crt"
tlsCertFile: "/var/lib/kubelet/$worker.crt"
tlsPrivateKeyFile: "/var/lib/kubelet/$worker.key"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.96.0.10"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
EOF
    done

printc "\n# Criando kube-proxy-config.yaml\n"
cat <<EOF | sudo tee $PATH_CONFIG/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "$NET_CIDR.0/24"
EOF

printc "\n# Criando kubelet systemd\n"
cat <<EOF | sudo tee $PATH_CONFIG/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

printc "\n# Criando kube-proxy systemd\n"
cat <<EOF | sudo tee $PATH_CONFIG/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

printc "\n# Criando diretorio de configuracao dos nodes\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            sudo mkdir -v -p \
            /var/lib/kubelet \
            /var/lib/kube-proxy \
            /var/lib/kubernetes \
            /var/run/kubernetes
        "
    done

printc "\n# Download binarios dos nodes $K8S_VERSION\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            wget -q --show-progress --https-only --timestamping \
            https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kubectl \
            https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kube-proxy \
            https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kubelet
        "
    done

printc "\n# Instalando binarios nos nodes\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        vagrant ssh $worker -c " 
            chmod -v +x kubectl kube-proxy kubelet
            sudo mv -v kubectl kube-proxy kubelet /usr/local/bin/
        "
    done

printc "\n# Configurando os nodes\n"
    for worker in worker-{1..2}; do
        printc "\n$worker\n" "yellow"
        for file in \
            $PATH_CERT/ca.crt \
            $PATH_CERT/$worker.crt $PATH_CERT/$worker.key \
            $PATH_CONFIG/$worker.kubeconfig \
            $PATH_CONFIG/kubelet-config-$worker.yaml \
            $PATH_CONFIG/kube-proxy.kubeconfig \
            $PATH_CONFIG/kube-proxy-config.yaml \
            $PATH_CONFIG/kubelet.service \
            $PATH_CONFIG/kube-proxy.service; do
            vagrant scp ${file} ${worker}:~/
        done
        vagrant ssh $worker -c "
            sudo mv -v ca.crt /var/lib/kubernetes/
            sudo mv -v $worker.crt $worker.key /var/lib/kubelet/
            sudo mv -v $worker.kubeconfig /var/lib/kubelet/kubeconfig
            sudo mv -v kubelet-config-$worker.yaml kubelet-config.yaml 
            sudo mv -v kubelet-config.yaml /var/lib/kubelet/
            sudo mv -v kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
            sudo mv -v kube-proxy-config.yaml /var/lib/kube-proxy/
            sudo mv -v kubelet.service /etc/systemd/system/
            sudo mv -v kube-proxy.service /etc/systemd/system/
        "
        vagrant ssh $worker -c "
            sudo systemctl daemon-reload
            sudo systemctl enable kubelet kube-proxy
            sudo systemctl start kubelet kube-proxy
        "
    done

printc "\n# Validando os nodes\n"
    vagrant ssh master-1 -c "
        sleep 15
        kubectl get nodes
    "
