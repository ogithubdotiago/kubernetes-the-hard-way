> Este material é uma cópia dos materiais originais [kelseyhightower](https://github.com/kelseyhightower/kubernetes-the-hard-way) e [mmumshad/kodekloud](https://github.com/mmumshad/kubernetes-the-hard-way).

# Kubernetes The Hard Way via VirtualBox

Este tutorial orienta uma instalação de kubernetes no modo "the hard way" por Virtualbox com auxilio de scripts via shell script.

## Detalhes do ambiente

* [Ubuntu](https://app.vagrantup.com/ubuntu/boxes/jammy64) v22.04
* [Virtualbox](https://www.virtualbox.org/wiki/Downloads) v6.1.32
* [Vagrant](https://www.vagrantup.com/downloads) v2.2.19
* [HAProxy](http://www.haproxy.org/#down) v2.4.14

## Detalhes do cluster

* [Kubernetes](https://github.com/kubernetes/kubernetes) v1.20.0
* [Containerd](https://github.com/containerd/containerd) v1.5.10
* [CNI](https://github.com/containernetworking/cni) v1.1.1
* [Weave Net](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/) v2.8.1
* [etcd](https://github.com/coreos/etcd) v3.5.0
* [CoreDNS](https://github.com/coredns/coredns) v1.9.3

## Laboratório

#### Definir path para diretorio do vagrant
```bash
export VAGRANT_CWD="$(pwd)/vagrant/"
```

#### Instalação de dependências
```bash
bash 01-configure-prerequisites.sh
```

#### Instalação maquinas virtuais
```bash
vagrant up
```

#### Instalação kubernetes
```bash
bash bootstrapping.sh
```