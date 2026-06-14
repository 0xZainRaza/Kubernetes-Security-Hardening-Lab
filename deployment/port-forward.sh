#!/bin/bash

# ================================================
# Kubernetes Security Hardening Lab - Port Forward
# Exposes all scenarios + ArgoCD + Linkerd Viz
# ================================================

export KUBECONFIG=~/.kube/config

echo "[*] Killing existing port-forwards..."
pkill -f "kubectl port-forward" 2>/dev/null
sleep 2

echo "[*] Starting port-forwards..."

# Scenario 01 - Sensitive Keys
POD=$(kubectl get pods -n default -l app=build-code \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
[ -n "$POD" ] && kubectl port-forward $POD \
  --address 0.0.0.0 1230:3000 > /dev/null 2>&1 &
echo "[+] Scenario 01 - Sensitive Keys      → http://0.0.0.0:1230"

# Scenario 02 - DIND Exploitation
POD=$(kubectl get pods -n default -l app=health-check \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
[ -n "$POD" ] && kubectl port-forward $POD \
  --address 0.0.0.0 1231:80 > /dev/null 2>&1 &
echo "[+] Scenario 02 - DIND Exploitation   → http://0.0.0.0:1231"

# Scenario 03 - SSRF
POD=$(kubectl get pods -n default -l app=internal-proxy \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
[ -n "$POD" ] && kubectl port-forward $POD \
  --address 0.0.0.0 1232:3000 > /dev/null 2>&1 &
echo "[+] Scenario 03 - SSRF                → http://0.0.0.0:1232"

# Scenario 05 - System Monitor
POD=$(kubectl get pods -n default -l app=system-monitor \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
[ -n "$POD" ] && kubectl port-forward $POD \
  --address 0.0.0.0 1233:8080 > /dev/null 2>&1 &
echo "[+] Scenario 05 - System Monitor      → http://0.0.0.0:1233"

# Kubernetes Goat Home
POD=$(kubectl get pods -n default -l app=kubernetes-goat-home \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
[ -n "$POD" ] && kubectl port-forward $POD \
  --address 0.0.0.0 1234:80 > /dev/null 2>&1 &
echo "[+] Goat Home Dashboard               → http://0.0.0.0:1234"

# Scenario 07 - Poor Registry
POD=$(kubectl get pods -n default -l app=poor-registry \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
[ -n "$POD" ] && kubectl port-forward $POD \
  --address 0.0.0.0 1235:5000 > /dev/null 2>&1 &
echo "[+] Scenario 07 - Poor Registry       → http://0.0.0.0:1235"

# Scenario 12 - Namespace Bypass
POD=$(kubectl get pods -n big-monolith -l app=hunger-check \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
[ -n "$POD" ] && kubectl --namespace big-monolith port-forward $POD \
  --address 0.0.0.0 1236:8080 > /dev/null 2>&1 &
echo "[+] Scenario 12 - Namespace Bypass    → http://0.0.0.0:1236"

# Scenario 11 - Cache Store
POD=$(kubectl get pods -n secure-middleware -l app=cache-store \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
[ -n "$POD" ] && kubectl --namespace secure-middleware port-forward $POD \
  --address 0.0.0.0 1237:6379 > /dev/null 2>&1 &
echo "[+] Scenario 11 - Cache Store         → http://0.0.0.0:1237"

# ArgoCD Dashboard
kubectl port-forward svc/argocd-server \
  --address 0.0.0.0 8080:443 -n argocd > /dev/null 2>&1 &
echo "[+] ArgoCD Dashboard                  → https://0.0.0.0:8080"

# Linkerd Viz Dashboard
kubectl port-forward svc/web \
  --address 0.0.0.0 8084:8084 -n linkerd-viz > /dev/null 2>&1 &
echo "[+] Linkerd Dashboard                 → http://0.0.0.0:8084"

echo ""
echo "================================================"
echo " All services exposed!"
echo ""
echo " Azure NSG ports needed:"
echo " 1230-1237 → Kubernetes Goat scenarios"
echo " 8080      → ArgoCD dashboard"
echo " 8084      → Linkerd Viz dashboard"
echo ""
echo " ArgoCD credentials:"
echo -n " Password: "
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo " Username: admin"
echo "================================================"