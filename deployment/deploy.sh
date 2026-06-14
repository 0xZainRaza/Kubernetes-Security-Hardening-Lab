#!/bin/bash

# ================================================
# Kubernetes Security Hardening Lab - Deploy Script
# Deploys: Kubernetes Goat + ArgoCD + Kyverno + Linkerd
# ================================================

# ================================================
# Kubernetes Security Hardening Lab - Deploy Script
# ================================================

# Ensure kubectl and linkerd are available
export KUBECONFIG=~/.kube/config
export PATH=$PATH:/usr/local/bin:$HOME/.linkerd2/bin

# Wait for k3s to be ready
echo "[*] Waiting for k3s to be ready..."
until kubectl get nodes 2>/dev/null; do
  echo "    k3s not ready yet, waiting 5 seconds..."
  sleep 5
done
echo "[+] k3s is ready!"




export KUBECONFIG=~/.kube/config
export PATH=$PATH:$HOME/.linkerd2/bin

REPO_DIR="$(dirname "$0")/.."
SCENARIOS_DIR="$REPO_DIR/kubernetes-goat/scenarios"

# ================================================
# STEP 1 - Deploy Kubernetes Goat scenarios
# ================================================
echo ""
echo "[*] STEP 1 - Deploying Kubernetes Goat scenarios..."

kubectl apply -f $SCENARIOS_DIR/batch-check/job.yaml
kubectl apply -f $SCENARIOS_DIR/build-code/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/cache-store/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/health-check/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/hunger-check/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/internal-proxy/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/kubernetes-goat-home/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/poor-registry/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/system-monitor/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/hidden-in-layers/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/insecure-rbac/setup.yaml
kubectl apply -f $SCENARIOS_DIR/docker-bench-security/deployment.yaml
kubectl apply -f $SCENARIOS_DIR/kube-bench-security/master-job.yaml
kubectl apply -f $SCENARIOS_DIR/kube-bench-security/node-job.yaml

echo "[*] Deploying metadata-db via Helm (SSRF scenario)..."
helm install metadata-db $SCENARIOS_DIR/metadata-db 2>/dev/null || \
  echo "[!] metadata-db already installed, skipping..."

echo "[+] Kubernetes Goat deployed!"

# ================================================
# STEP 2 - Install ArgoCD
# ================================================
echo ""
echo "[*] STEP 2 - Installing ArgoCD..."

kubectl create namespace argocd 2>/dev/null || true

# Fix ApplicationSet CRD size issue
kubectl delete crd applicationsets.argoproj.io 2>/dev/null || true

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Fix ApplicationSet CRD with server-side apply
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/applicationset-crd.yaml \
  --server-side 2>/dev/null || true

echo "[*] Waiting for ArgoCD pods..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd \
  --timeout=300s

# Configure ArgoCD to treat Jobs as Healthy
kubectl patch configmap argocd-cm -n argocd --type merge -p \
  '{"data":{"resource.customizations.health.batch_Job":"hs = {}\nhs.status = \"Healthy\"\nhs.message = \"Job running as expected\"\nreturn hs\n"}}'

# Register GitHub repo
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: kubernetes-security-hardening-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/0xZainRaza/Kubernetes-Security-Hardening
EOF

echo "[+] ArgoCD installed!"

# ================================================
# STEP 3 - Apply ArgoCD Applications
# ================================================
echo ""
echo "[*] STEP 3 - Applying ArgoCD Applications..."

kubectl apply -f $REPO_DIR/argocd/apps/app-kubernetes-goat.yaml

echo "[+] ArgoCD Applications applied!"

# ================================================
# STEP 4 - Install Kyverno
# ================================================
echo ""
echo "[*] STEP 4 - Installing Kyverno..."

helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
helm repo update

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace 2>/dev/null || \
  echo "[!] Kyverno already installed, skipping..."

echo "[*] Waiting for Kyverno pods..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=kyverno \
  -n kyverno \
  --timeout=300s

echo "[*] Applying Kyverno policies..."
kubectl apply -f $REPO_DIR/kyverno/policies/

echo "[+] Kyverno installed and policies applied!"

# ================================================
# STEP 5 - Install Linkerd
# ================================================
echo ""
echo "[*] STEP 5 - Installing Linkerd..."

# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# Validate cluster
linkerd check --pre

# Install Linkerd CRDs
linkerd install --crds | kubectl apply -f -

# Install Linkerd control plane
linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -

echo "[*] Waiting for Linkerd pods..."
kubectl wait --for=condition=ready pod \
  -l linkerd.io/control-plane-component=identity \
  -n linkerd \
  --timeout=300s

# Verify installation
linkerd check

# Install Linkerd Viz
linkerd viz install \
  --set dashboard.enforcedHostRegexp=".*" | kubectl apply -f -

echo "[+] Linkerd installed!"

# ================================================
# STEP 6 - Inject Linkerd into namespaces
# ================================================
echo ""
echo "[*] STEP 6 - Injecting Linkerd sidecars..."

kubectl annotate namespace default \
  linkerd.io/inject=enabled --overwrite
kubectl annotate namespace big-monolith \
  linkerd.io/inject=enabled --overwrite
kubectl annotate namespace secure-middleware \
  linkerd.io/inject=enabled --overwrite

# Restart pods to inject sidecars
kubectl delete pods --all -n default 2>/dev/null || true
kubectl delete pods --all -n big-monolith 2>/dev/null || true
kubectl delete pods --all -n secure-middleware 2>/dev/null || true

echo "[*] Waiting for pods to restart with sidecars..."
sleep 30

echo "[+] Linkerd sidecars injected!"

# ================================================
# STEP 7 - Apply Linkerd AuthorizationPolicies
# ================================================
echo ""
echo "[*] STEP 7 - Applying Linkerd policies..."

kubectl apply -f $REPO_DIR/service-mesh/policies/

echo "[+] Linkerd policies applied!"

# ================================================
# DONE - Print summary
# ================================================
echo ""
echo "================================================"
echo " Deployment Complete!"
echo ""
echo " ArgoCD Dashboard:"
echo " URL: https://<VM-IP>:8080"
echo " Username: admin"
echo -n " Password: "
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo " Linkerd Dashboard:"
echo " URL: http://<VM-IP>:8084"
echo ""
echo " Run deployment/port-forward.sh to expose all services"
echo "================================================"
