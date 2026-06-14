# Kubernetes Security Hardening Lab 

A hands-on Kubernetes security project that deploys intentionally vulnerable workloads,
exploits them to demonstrate real attack vectors, and implements defense layers using
GitOps, Policy as Code, and a Service Mesh.

---

## Project Overview

This project combines offensive and defensive Kubernetes security techniques to demonstrate
a complete DevSecOps security pipeline. Vulnerable workloads from
[Kubernetes Goat](https://github.com/madhuakula/kubernetes-goat) are deployed, exploited,
and then hardened using industry-standard tools.

---

## Architecture

```
GitHub Repository (Source of Truth)
        │
        ▼
ArgoCD (GitOps)
        │
        ├── Kubernetes Goat (Vulnerable Workloads)
        ├── Kyverno (Policy as Code)
        └── Linkerd (Service Mesh)
        │
        ▼
k3s Cluster on Azure VM
        │
        ├── Attack Layer  → Kubernetes Goat scenarios
        ├── Defense Layer → Kyverno policies + Linkerd mTLS
        └── GitOps Layer  → ArgoCD self-heal + audit trail
```

---

## Stack

| Tool | Purpose |
|---|---|
| **Azure VM** | Cloud infrastructure (Ubuntu 24.04) |
| **k3s** | Lightweight Kubernetes distribution |
| **Docker** | Container runtime |
| **Kubernetes Goat** | Intentionally vulnerable workloads |
| **ArgoCD** | GitOps continuous deployment |
| **Kyverno** | Policy as Code admission controller |
| **Linkerd** | Service mesh with mTLS |

---

## Project Structure

```
Kubernetes-Security-Hardening/
├── deployment/
│   ├── install.sh              # Install Docker, k3s, Linkerd CLI
│   ├── deploy.sh               # Deploy everything end to end
│   └── port-forward.sh         # Expose all services
│
├── kubernetes-goat/
│   ├── kustomization.yaml      # ArgoCD entry point
│   └── scenarios/              # 15 vulnerable scenarios
│
├── argocd/
│   └── apps/
│       └── app-kubernetes-goat.yaml
│
├── kyverno/
│   └── policies/
│       ├── no-privileged-containers.yaml
│       ├── no-hostpath-mounts.yaml
│       ├── require-resource-limits.yaml
│       ├── no-root-user.yaml
│       ├── no-nodeport-services.yaml
│       └── allowed-registries.yaml
│
└── service-mesh/
    └── policies/
        └── deny-cross-namespace.yaml

```

---

## Quick Start

### Prerequisites

- Azure account
- Ubuntu 22.04/24.04 VM (Standard_D4s_v3 — 4 vCPU, 16GB RAM)
- Git

### Installation

```bash
# Clone the repo
git clone https://github.com/0xZainRaza/Kubernetes-Security-Hardening.git
cd Kubernetes-Security-Hardening

# Step 1 - Install dependencies
chmod +x deployment/*.sh
bash deployment/install.sh

# Step 2 - Deploy everything
bash deployment/deploy.sh

# Step 3 - Expose services
bash deployment/port-forward.sh
```

### Access Dashboards

| Service | URL | Credentials |
|---|---|---|
| ArgoCD | https://\<VM-IP\>:8080 | admin / see deploy output |
| Linkerd Viz | http://\<VM-IP\>:8084 | none |
| Kubernetes Goat Home | http://\<VM-IP\>:1234 | none |

---

## Scenarios Exploited

| # | Scenario | Attack | MITRE ATT&CK | Defense |
|---|---|---|---|---|
| 1 | Sensitive Keys in Codebase | .git exposed → AWS credentials via git-dumper + gitleaks | T1552.001 | Multi-stage Docker builds |
| 2 | DIND Exploitation | Docker socket mounted → container escape | T1611 | Kyverno: no-hostpath-mounts |
| 3 | SSRF in Kubernetes | Internal service enum, CoreDNS metrics leaked topology | T1552.005 | Linkerd mTLS AuthorizationPolicy |
| 4 | Container Escape | Privileged container + HostPath → host filesystem access | T1611 | Kyverno: no-privileged-containers |
| 7 | Attacking Private Registry | Unauthenticated registry → pull/push any image | T1552 | Kyverno: allowed-registries |
| 8 | NodePort Exposure | NodePort service directly accessible from internet | T1133 | Kyverno: no-nodeport-services |
| 10 | Crypto Miner | Malicious image with hidden miner in Docker layers | T1496 | Kyverno: allowed-registries |
| 11 | Namespace Bypass | Cross-namespace Redis access → SECRETSTUFF key stolen | T1599 | Linkerd: deny-cross-namespace |
| 12 | Environment Info | printenv → VAULTAPIKEY + WEBHOOKAPIKEY exposed | T1552 | Kyverno: no-root-user |
| 13 | DoS Resources | No resource limits → cluster resource exhaustion | T1496 | Kyverno: require-resource-limits |
| 15 | Hidden in Layers | Docker layer extraction → secret.txt in deleted layer | T1552 | Multi-stage Docker builds |

---

## Defense Layers

### Layer 1 — GitOps (ArgoCD)

- Every change must go through GitHub — no direct kubectl changes
- Self-heal reverts manual changes within seconds
- Full audit trail in git history
- Prune removes resources deleted from repo
- **Proven:** deleted deployment restored in 12 seconds

### Layer 2 — Policy as Code (Kyverno)

| Policy | What it blocks | Scenario |
|---|---|---|
| no-privileged-containers | Container escape to host | Scenario 4 |
| no-hostpath-mounts | Docker socket exploitation | Scenario 2 |
| require-resource-limits | DoS + crypto mining | Scenario 13 |
| no-root-user | Credential exposure impact | Scenario 12 |
| no-nodeport-services | Internet service exposure | Scenario 8 |
| allowed-registries | Unknown image sources | Scenario 10 |

### Layer 3 — Service Mesh (Linkerd)

- Automatic mTLS encryption between all pods
- AuthorizationPolicy enforces zero trust networking
- deny-cross-namespace blocks unauthorized Redis access
- **Proven:** hacker-container → Redis returns `Error: Server closed the connection`

---

## Attribution

Vulnerable workloads sourced from [Kubernetes Goat](https://github.com/madhuakula/kubernetes-goat)
by Madhu Akula, used under the MIT License.
Manifests wrapped with Kustomize for ArgoCD GitOps deployment.

---
