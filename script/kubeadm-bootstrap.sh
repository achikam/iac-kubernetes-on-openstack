#!/bin/bash
# echo "TESTING" > /tmp/TERRAFORM.txt

VIP=10.20.20.10
cat << EOF | tee ~/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: 1.28.1
controlPlaneEndpoint: "10.20.20.11:6443"
networking:
  podSubnet: 10.244.0.0/16
EOF

# Setup Container
sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock
sudo cat /etc/crictl.yaml

sudo kubeadm init --config ~/kubeadm-config.yaml --upload-certs | tee kubeadm-init.out
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sudo kubeadm config print init-defaults
sudo apt-get install bash-completion -y
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

grep -A2 "kubeadm join" kubeadm-init.out | sed -n '1,3p' > kubeadm-join-master.sh
grep -A2 "kubeadm join" kubeadm-init.out | sed -n '5,6p' > kubeadm-join-worker.sh

# grep -A2 "kubeadm join" terraform_apply.log | cut -d':' -f2- | sed -n '1,3p'
# grep -A2 "kubeadm join" terraform_apply.log | cut -d':' -f2- | sed -n '5,6p'