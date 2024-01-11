#!/bin/bash

# kubeadm join 10.20.20.11:6443 --token kjc5x1.mk2dgty5e54otup2 \
# --discovery-token-ca-cert-hash sha256:317bfbb769243d0e1ce9c137f1526a319484ee734f5f212b46b8a353105d5d97

# kubeadm token list | grep authentication | grep -Eo '^[a-zA-Z0-9.-]+'
# openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'

sudo chmod 600 ~/.ssh/id_rsa
scp -o StrictHostKeyChecking=no kubeadm-join-worker.sh ubuntu@${each.value.privateip}:/tmp/
ssh -o StrictHostKeyChecking=no ubuntu@${each.value.privateip} 'sudo bash /tmp/kubeadm-join-worker.sh'
