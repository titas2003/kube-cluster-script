#!/bin/bash

set -e

echo "=== Disable SELinux ==="
setenforce 0 || true
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "=== Load kernel modules ==="
dnf install -y kernel-modules kernel-modules-extra
modprobe overlay
modprobe br_netfilter

cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

echo "=== Configure sysctl for Kubernetes ==="
cat <<EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

echo "=== Disable swap ==="
swapoff -a
sed -i '/swap/s/^/#/g' /etc/fstab

echo "=== Install containerd ==="
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf makecache
dnf install -y containerd.io

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable --now containerd
systemctl restart containerd

echo "=== Add Kubernetes repo ==="
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

dnf makecache

echo "=== Install Kubernetes components ==="
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

systemctl enable --now kubelet

echo "=== Pull Kubernetes images ==="
kubeadm config images pull

sudo kubeadm init phase upload-certs --upload-certs

#create firsh master
echo "=== create the Kubernetes main master ==="

echo "=== Worker node successfully joined the cluster ==="
