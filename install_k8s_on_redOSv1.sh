#!/bin/bash

#Данный скрипт производит автоматическую настройку k8s версии 1.26.8 и containerd 1.7.5 последняя версия на данный момент.
#Скрипт сможет поставить k8s с версии 1.26.0 и до 1.28.1 было протестировано. Не забудьте только заменить значения на строке 37
hostnamectl set-hostname 'k8s-master'
setenforce 0
dnf update -y
swapoff -a
swapoff -a && sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
setenforce 0 && sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
cat <<EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

cat <<EOF > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

modprobe overlay
modprobe br_netfilter
sysctl --system

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
dnf install kubelet-1.26.8 kubeadm-1.26.8 kubectl-1.26.8 cri-tools containerd -y

wget https://github.com/containerd/containerd/releases/download/v1.7.5/containerd-1.7.5-linux-amd64.tar.gz && tar xvf containerd-1.7.5-linux-amd64.tar.gz
systemctl stop containerd
cd bin
yes | cp -rf * /usr/bin
systemctl start containerd
containerd --version
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl enable --now containerd
systemctl restart containerd
systemctl enable kubelet.service

kubeadm config images pull
kubeadm init --pod-network-cidr=192.168.0.0/16
wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml
#Если нужен будет nginx ingress просто раскоментировать стр 55, 61, 60
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