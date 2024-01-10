#!/bin/bash

sudo apt-get remove needrestart -y
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y vim git tmux
sudo apt install curl apt-transport-https vim git wget software-properties-common lsb-release ca-certificates -y
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo modprobe overlay
sudo modprobe br_netfilter
sudo touch /etc/sysctl.d/kubernetes.conf
sudo echo "net.bridge.bridge-nf-call-ip6tables = 1" > /etc/sysctl.d/kubernetes.conf
sudo echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/kubernetes.conf
sudo echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/kubernetes.conf

sudo sysctl --system
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt-get install containerd.io -y
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml
sudo systemctl restart containerd

sudo echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y kubeadm=1.28.1-00 kubelet=1.28.1-00 kubectl=1.28.1-00
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
sudo systemctl start kubelet