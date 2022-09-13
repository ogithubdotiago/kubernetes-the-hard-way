# Kubernetes The Hard Way

> Este material é uma cópia dos materiais originais [kelseyhightower](https://github.com/kelseyhightower/kubernetes-the-hard-way) e [mmumshad/kodekloud](https://github.com/mmumshad/kubernetes-the-hard-way) para fins educacionais.

Instalação cluster kubernetes no modo "The Hard Way" via Virtualbox com auxilio de scripts.

## Detalhes do ambiente

| descricao | version |
|:----------|:--------|
| ubuntu    | 22.04   |
| qemu      | 6.2.0   |
| libvirtd  | 8.0.0   |
| vagrant   | 2.2.19  |
| haproxy   | 2.4.14  |

## Detalhes do cluster

| descricao  | version |
|:-----------|:--------|
| kubernetes | 1.20.8  |
| containerd | 1.5.10  |
| cni        | 1.1.1   |
| weave net  | 2.8.1   |
| calico     | 3.20.0  |
| etcd       | 3.5.0   |
| coredns    | 1.9.3   |

## Laboratório

#### Info maquinas virtuais

> Para acessar as maquinas virtuais, vagrant ssh \<hostname\>

| hostname     | ip address    |
|--------------|---------------|
| master-1     | 192.168.56.11 |
| master-2     | 192.168.56.11 |
| worker-1     | 192.168.56.21 |
| worker-2     | 192.168.56.22 |
| lb-1         | 192.168.56.30 |

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
