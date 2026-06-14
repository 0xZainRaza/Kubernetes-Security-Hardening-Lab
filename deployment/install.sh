#!/bin/bash

# ================================================
# Kubernetes Security Hardening Lab - Install Script
# Installs Docker, k3s, Helm on Ubuntu 22.04/24.04
# ================================================

echo "[*] Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

echo "[*] Installing dependencies..."
sudo apt-get install -y curl wget git socat

echo "[*] Installing Docker..."
curl -fsSL https://get.docker.com | sh

# Add user to docker group without newgrp (causes script to stop)
sudo usermod -aG docker $USER

echo "[*] Verifying Docker..."
sudo docker --version

echo "[*] Installing k3s with Docker runtime..."
curl -sfL https://get.k3s.io | sh -s - --docker

echo "[*] Configuring kubectl..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config
echo "export KUBECONFIG=~/.kube/config" >> ~/.bashrc

echo "[*] Verifying k3s..."
kubectl get nodes

echo "[*] Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[*] Verifying Helm..."
helm version

echo "[*] Installing Linkerd CLI..."
curl -fsL https://run.linkerd.io/install-edge | sh
export PATH=$PATH:$HOME/.linkerd2/bin
echo "export PATH=\$PATH:\$HOME/.linkerd2/bin" >> ~/.bashrc

echo "[*] Verifying Linkerd CLI..."
linkerd version --client

echo ""
echo "================================================"
echo " Installation Complete!"
echo ""
echo " IMPORTANT: Run this before deploy.sh:"
echo " export KUBECONFIG=~/.kube/config"
echo " export PATH=\$PATH:\$HOME/.linkerd2/bin"
echo ""
echo " Then run:"
echo " bash deployment/deploy.sh"
echo "================================================"
