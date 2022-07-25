#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n#############################\n"
printc "# Configurando etcd cluster #\n"
printc "#############################\n"

printc "\n# Download etcd $ETCD_VERSION\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c " 
            wget -q --show-progress --https-only --timestamping \
            https://github.com/coreos/etcd/releases/download/$ETCD_VERSION/etcd-$ETCD_VERSION-linux-amd64.tar.gz
        "
    done

printc "\n# Instalando etcd\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c "
            tar -xvf etcd-$ETCD_VERSION-linux-amd64.tar.gz
            sudo mv -v etcd-$ETCD_VERSION-linux-amd64/etcd* /usr/local/bin/
        "
    done

printc "\n# Copiando arquivos etcd\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        for file in \
            $PATH_CERT/ca.crt \
            $PATH_CERT/etcd-server.crt $PATH_CERT/etcd-server.key ; do
            vagrant scp ${file} ${master}:~/
        done
        vagrant ssh $master -c "
            sudo mkdir -v -p /etc/etcd /var/lib/etcd
            sudo cp -v ca.crt etcd-server.key etcd-server.crt /etc/etcd/
        "
    done

printc "\n# Configurando etcd\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        for file in \
            $PATH_CONFIG/get_hostname.sh \
            $PATH_CONFIG/get_internal_ip.sh ; do
            vagrant scp ${file} ${master}:~/
        done
        GET_INTERNAL_IP=$(vagrant ssh $master -c "bash get_internal_ip.sh")
        GET_ETCD_NAME=$(vagrant ssh $master -c "bash get_hostname.sh")
        INTERNAL_IP="${GET_INTERNAL_IP/$'\r'/}"
        ETCD_NAME="${GET_ETCD_NAME/$'\r'/}"

        cat <<-EOF | sudo tee $PATH_CONFIG/etcd_$master.service
		[Unit]
		Description=etcd
		Documentation=https://github.com/coreos
		
		[Service]
		ExecStart=/usr/local/bin/etcd \\
		  --name ${ETCD_NAME} \\
		  --cert-file=/etc/etcd/etcd-server.crt \\
		  --key-file=/etc/etcd/etcd-server.key \\
		  --peer-cert-file=/etc/etcd/etcd-server.crt \\
		  --peer-key-file=/etc/etcd/etcd-server.key \\
		  --trusted-ca-file=/etc/etcd/ca.crt \\
		  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
		  --peer-client-cert-auth \\
		  --client-cert-auth \\
		  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
		  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
		  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
		  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
		  --initial-cluster-token etcd-cluster-0 \\
		  --initial-cluster master-1=https://$NET_CIDR.11:2380,master-2=https://$NET_CIDR.12:2380 \\
		  --initial-cluster-state new \\
		  --data-dir=/var/lib/etcd
		Restart=on-failure
		RestartSec=5
		
		[Install]
		WantedBy=multi-user.target
		EOF
        printc "$(ls -1 $PATH_CONFIG/etcd_$master.service)\n" "yellow"

        for file in \
            $PATH_CONFIG/etcd_$master.service ; do
            vagrant scp ${file} ${master}:~/
        done
        vagrant ssh $master -c "
            sudo mv -v etcd_$master.service /etc/systemd/system/etcd.service
            sudo systemctl daemon-reload
            sudo systemctl enable etcd
            sudo systemctl start etcd
        "
    done

printc "\n# Validando etcd\n"
    for master in master-{1..2}; do
        printc "\n$master\n" "yellow"
        vagrant ssh $master -c "
            sudo ETCDCTL_API=3 etcdctl member list \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/etcd/ca.crt \
            --cert=/etc/etcd/etcd-server.crt \
            --key=/etc/etcd/etcd-server.key
        "
    done
