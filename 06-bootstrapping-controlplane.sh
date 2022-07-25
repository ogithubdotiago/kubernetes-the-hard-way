#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n#################################################\n"
printc "# Configurando Kubernetes Control Plane cluster #\n"
printc "#################################################\n"

printc "\n# Download binarios control-plane $K8S_VERSION\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c " 
            wget -q --show-progress --https-only --timestamping \
            https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kube-apiserver \
            https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kube-controller-manager \
            https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kube-scheduler \
            https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kubectl \
            https://github.com/ahmetb/kubectx/releases/download/$KUBECTX_VERSION/kubectx \
            https://github.com/ahmetb/kubectx/releases/download/$KUBENS_VERSION/kubens
        "
    done

printc "\n# Instalando binarios control-plane\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c "
            chmod -v +x kube-apiserver kube-controller-manager kube-scheduler kubectl kubectx kubens
            sudo mv -v kube-apiserver kube-controller-manager kube-scheduler kubectl kubectx kubens /usr/local/bin/
        "
    done

printc "\n# Configurando kube-apiserver\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        for file in \
            $PATH_CONFIG/admin.kubeconfig \
            $PATH_CERT/ca.crt $PATH_CERT/ca.key \
            $PATH_CERT/kube-apiserver.crt $PATH_CERT/kube-apiserver.key \
            $PATH_CERT/service-account.key $PATH_CERT/service-account.crt \
            $PATH_CERT/etcd-server.key $PATH_CERT/etcd-server.crt \
            $PATH_CERT/ca-login.crt \
            $PATH_CONFIG/encryption-config.yaml; do
            vagrant scp ${file} ${master}:~/
        done
        vagrant ssh $master -c "
            sudo mkdir -v -p /var/lib/kubernetes/
            sudo mkdir -v -p ~/.kube/
            sudo mv -v ca.crt ca.key \
            kube-apiserver.crt kube-apiserver.key \
            service-account.key service-account.crt \
            etcd-server.key etcd-server.crt \
            encryption-config.yaml /var/lib/kubernetes/
            sudo mv -v admin.kubeconfig ~/.kube/config
            sudo mv -v ca-login.crt /var/lib/kubernetes/
        "

        GET_INTERNAL_IP=$(vagrant ssh $master -c "bash get_internal_ip.sh")
        INTERNAL_IP="${GET_INTERNAL_IP/$'\r'/}"
        cat <<-EOF | sudo tee $PATH_CONFIG/kube-apiserver-$master.service
		[Unit]
		Description=Kubernetes API Server
		Documentation=https://github.com/kubernetes/kubernetes
		
		[Service]
		ExecStart=/usr/local/bin/kube-apiserver \\
		  --advertise-address=${INTERNAL_IP} \\
		  --allow-privileged=true \\
		  --apiserver-count=3 \\
		  --audit-log-maxage=30 \\
		  --audit-log-maxbackup=3 \\
		  --audit-log-maxsize=100 \\
		  --audit-log-path=/var/log/audit.log \\
		  --authorization-mode=Node,RBAC \\
		  --bind-address=0.0.0.0 \\
		  --client-ca-file=/var/lib/kubernetes/ca.crt \\
		  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
		  --etcd-cafile=/var/lib/kubernetes/ca.crt \\
		  --etcd-certfile=/var/lib/kubernetes/etcd-server.crt \\
		  --etcd-keyfile=/var/lib/kubernetes/etcd-server.key \\
		  --etcd-servers=https://$NET_CIDR.11:2379,https://$NET_CIDR.12:2379 \\
		  --event-ttl=1h \\
		  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
		  --kubelet-certificate-authority=/var/lib/kubernetes/ca.crt \\
		  --kubelet-client-certificate=/var/lib/kubernetes/kube-apiserver.crt \\
		  --kubelet-client-key=/var/lib/kubernetes/kube-apiserver.key \\
		  --runtime-config='api/all=true' \\
		  --service-account-key-file=/var/lib/kubernetes/service-account.crt \\
		  --service-account-signing-key-file=/var/lib/kubernetes/service-account.key \\
		  --service-account-issuer=https://${IP_LB_MASTER}:6443 \\
		  --service-cluster-ip-range=$NET_CIDR_SVC \\
		  --service-node-port-range=30000-32767 \\
		  --tls-cert-file=/var/lib/kubernetes/kube-apiserver.crt \\
		  --tls-private-key-file=/var/lib/kubernetes/kube-apiserver.key \\
		  --oidc-issuer-url=https://$IP_LB_WORKER:32000 \\
		  --oidc-client-id=gangway \\
		  --oidc-ca-file=/var/lib/kubernetes/ca-login.crt \\
		  --oidc-username-claim=email \\
		  --oidc-groups-claim=groups \\
		  --v=2
		Restart=on-failure
		RestartSec=5
		
		[Install]
		WantedBy=multi-user.target
		EOF
        printc "$(ls -1 $PATH_CONFIG/kube-apiserver-$master.service)\n" "yellow"

        vagrant scp $PATH_CONFIG/kube-apiserver-$master.service ${master}:~/
        vagrant ssh $master -c "
            sudo mv -v kube-apiserver-$master.service /etc/systemd/system/kube-apiserver.service
            sudo systemctl daemon-reload
            sudo systemctl enable kube-apiserver
            sudo systemctl restart kube-apiserver
        "
    done

printc "\n# Configurando kube-controller-manager\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant scp $PATH_CONFIG/kube-controller-manager.kubeconfig ${master}:~/
        vagrant ssh $master -c "
            sudo cp -v kube-controller-manager.kubeconfig /var/lib/kubernetes/
        "

        cat <<-EOF | sudo tee $PATH_CONFIG/kube-controller-manager.service
		[Unit]
		Description=Kubernetes Controller Manager
		Documentation=https://github.com/kubernetes/kubernetes
		
		[Service]
		ExecStart=/usr/local/bin/kube-controller-manager \\
		  --address=0.0.0.0 \\
		  --cluster-cidr=$NET_CIDR_POD \\
		  --cluster-name=kubernetes \\
		  --cluster-signing-cert-file=/var/lib/kubernetes/ca.crt \\
		  --cluster-signing-key-file=/var/lib/kubernetes/ca.key \\
		  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
		  --leader-elect=true \\
		  --root-ca-file=/var/lib/kubernetes/ca.crt \\
		  --service-account-private-key-file=/var/lib/kubernetes/service-account.key \\
		  --service-cluster-ip-range=$NET_CIDR_SVC \\
		  --use-service-account-credentials=true \\
		  --v=2
		Restart=on-failure
		RestartSec=5
		
		[Install]
		WantedBy=multi-user.target
		EOF
        printc "$(ls -1 $PATH_CONFIG/kube-controller-manager.service)\n" "yellow"

        vagrant scp $PATH_CONFIG/kube-controller-manager.service ${master}:~/
        vagrant ssh $master -c "
            sudo mv -v kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service
            sudo systemctl daemon-reload
            sudo systemctl enable kube-controller-manager
            sudo systemctl restart kube-controller-manager
        "
    done

printc "\n# Configurando kube-scheduler\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant scp $PATH_CONFIG/kube-scheduler.kubeconfig ${master}:~/
        vagrant ssh $master -c "
            sudo cp -v kube-scheduler.kubeconfig /var/lib/kubernetes/
        "

        cat <<-EOF | sudo tee $PATH_CONFIG/kube-scheduler.service
		[Unit]
		Description=Kubernetes Scheduler
		Documentation=https://github.com/kubernetes/kubernetes
		
		[Service]
		ExecStart=/usr/local/bin/kube-scheduler \\
		  --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig \\
		  --address=127.0.0.1 \\
		  --leader-elect=true \\
		  --v=2
		Restart=on-failure
		RestartSec=5
		
		[Install]
		WantedBy=multi-user.target
		EOF
        printc "$(ls -1 $PATH_CONFIG/kube-scheduler.service)\n" "yellow"

        vagrant scp $PATH_CONFIG/kube-scheduler.service ${master}:~/
        vagrant ssh $master -c "
            sudo mv -v kube-scheduler.service /etc/systemd/system/kube-scheduler.service
            sudo systemctl daemon-reload
            sudo systemctl enable kube-scheduler.service
            sudo systemctl restart kube-scheduler.service
        "
    done
