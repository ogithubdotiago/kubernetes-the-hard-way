# Kubernetes The Hard Way

> Este material é uma cópia dos materiais originais [kelseyhightower](https://github.com/kelseyhightower/kubernetes-the-hard-way) e [mmumshad/kodekloud](https://github.com/mmumshad/kubernetes-the-hard-way) para fins educacionais.

Instalação cluster kubernetes no modo "The Hard Way" via Virtualbox com auxilio de scripts.

## Detalhes do ambiente

* [Ubuntu](https://app.vagrantup.com/ubuntu/boxes/jammy64) 22.04 LTS
* [Virtualbox](https://www.virtualbox.org/wiki/Downloads) v6.1.32
* [Vagrant](https://www.vagrantup.com/downloads) v2.2.19
* [HAProxy](http://www.haproxy.org/#down) v2.4.14

## Detalhes do cluster

* [Kubernetes](https://github.com/kubernetes/kubernetes) v1.20.0
* [Containerd](https://github.com/containerd/containerd) v1.5.10
* [CNI](https://github.com/containernetworking/cni) v1.1.1
* [Weave Net](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/) v2.8.1
* [Calico](https://projectcalico.docs.tigera.io/getting-started/kubernetes/) v3.20.0
* [etcd](https://github.com/coreos/etcd) v3.5.0
* [CoreDNS](https://github.com/coredns/coredns) v1.9.3

## Laboratório

#### Info maquinas virtuais

> Para acessar as maquinas virtuais, vagrant ssh \<hostname\>

| hostname     | ip address    |
|--------------|---------------|
| master-1     | 192.168.56.11 |
| master-2     | 192.168.56.11 |
| worker-1     | 192.168.56.21 |
| worker-2     | 192.168.56.22 |
| loadbalancer | 192.168.56.30 |

#### Definir path para diretorio do vagrant

> Definindo o VAGRANT_CWD, não é necessário rodar os comandos do vagrant dentro do path onde esta o arquivo Vagrantfile.

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

#### Instalação cluster kubernetes
```bash
bash bootstrapping.sh
```

#### URLs de acesso via loadbalancer (HAProxy)

| URL             | Endereço            |
|-----------------|---------------------|
| kube-apiserver  | 192.168.56.30:6443  |
| dex             | 192.168.56.40:32000 |
| gangway         | 192.168.56.40:32001 |
