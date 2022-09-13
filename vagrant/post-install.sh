#!/bin/bash

# clean default /etc/hosts
true > /etc/hosts

# Update /etc/hosts about other hosts
cat >> /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME} ${HOSTNAME}.localdomain

192.168.56.11  master-1
192.168.56.12  master-2
192.168.56.21  worker-1
192.168.56.22  worker-2
192.168.56.30  lb-1
192.168.56.40  lb-1
EOF

#configure DNS
sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
service systemd-resolved restart
