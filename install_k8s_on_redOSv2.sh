#!/bin/bash

#Данный скрипт производит автоматическую настройку k8s версии 1.26.8 и cri-o 1.23 последняя версия на данный момент.
#Скрипт сможет поставить k8s с версии 1.26.0 и до 1.28.1 было протестировано. Не забудьте только заменить значения на строке 45
hostnamectl set-hostname 'k8s-master'
setenforce 0
dnf update -y
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
modprobe overlay
modprobe br_netfilter

export VERSION=1.23
curl -L -o /etc/dnf.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_8/devel:kubic:libcontainers:stable.repo
curl -L -o /etc/dnf.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/CentOS_8/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
dnf install -y cri-o
systemctl enable crio
systemctl start crio

cat <<EOF > /etc/dnf.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/dnf/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/dnf/doc/dnf-key.gpg https://packages.cloud.google.com/dnf/doc/rpm-package-key.gpg
EOF

dnf update -y
dnf install -y kubelet-1.26.8 kubeadm-1.26.8 kubectl-1.26.8
dnf clean all
systemctl enable kubelet
kubeadm config images pull
kubeadm init --pod-network-cidr=192.168.0.0/16
wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml
#Если нужен будет nginx ingress просто раскоментировать стр 52, 58, 60
#wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/do/deploy.yaml
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" > /etc/environment
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
#kubectl create namespace ingress-nginx
kubectl apply -f calico.yaml
#kubectl apply -f deploy.yaml --namespace=ingress-nginx
kubectl taint nodes --all node-role.kubernetes.io/control-plane-