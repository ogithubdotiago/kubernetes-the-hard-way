#!/bin/bash

NET_CIDR=$1

# clean default /etc/hosts
true > /etc/hosts

# Update /etc/hosts about other hosts
cat >> /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME} ${HOSTNAME}.localdomain

${NET_CIDR}11  master-1
${NET_CIDR}12  master-2
${NET_CIDR}21  worker-1
${NET_CIDR}22  worker-2
${NET_CIDR}30  lb-1
${NET_CIDR}40  lb-1
EOF

#configure DNS
sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
service systemd-resolved restart
