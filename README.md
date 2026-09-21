# mediacatalog-infra

Kubernetes (k3s) homelab managed via ArgoCD GitOps. Runs media, workflow, resume, file-sharing,
and data-processing services on a small multi-node cluster with Traefik ingress and rclone-backed
cloud storage mounts.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Services](#services)
- [Custom Docker Images](#custom-docker-images)
- [Setup Order](#setup-order)
  - [1. Cluster (k3s)](#1-cluster-k3s)
  - [2. Firewall](#2-firewall)
  - [3. ArgoCD](#3-argocd)
  - [4. Argo Workflows](#4-argo-workflows)
  - [5. TLS Certificates (local dev)](#5-tls-certificates-local-dev)
  - [6. Secrets](#6-secrets)
  - [7. Deploy](#7-deploy)
- [CLI Tools](#cli-tools)
  - [Helm](#helm)
  - [Vault CLI](#vault-cli)
- [Maintenance](#maintenance)
  - [Resize kubelet mount](#resize-kubelet-mount)
  - [Patch a secret](#patch-a-secret)
  - [Remove SSH key for agent](#remove-ssh-key-for-agent)
- [Troubleshooting](#troubleshooting)
- [Backup](#backup)

---

## Prerequisites

- **k3s** cluster (server + agent nodes)
- **kubectl** configured with cluster access
- **ArgoCD CLI** (optional, for debugging)
- **mkcert** (macOS, for TLS cert generation)
- **croc** (optional, for transferring certs to server)
- Access to **ghcr.io** for pulling custom images

---

## Services

All manifests live in `app01/`. The main ingress (Traefik) routes by hostname for `.local`
domains and by path for legacy prefixes.

| Hostname / Path | Service | Purpose |
|---|---|---|
| `argocd.local` | ArgoCD | GitOps UI |
| `argo.local` | Argo Workflows | Workflow engine UI |
| `plex.local` | Plex | Media server (rclone fuse mount) |
| `s3.local` | SeaweedFS | S3-compatible object store |
| `n8n.local` | n8n | Workflow automation |
| `resume.local` | Reactive Resume | Resume builder |
| `mzworker.local` | mzworker | Deno data-processing worker |
| `immich.local` | Immich | Photo management (commented out) |
| `/streamer` | mediastreamer | Media streaming proxy |
| `/ytapi` | ytstreamer | YouTube-dl web frontend |
| `/pserve` | static-web-server | Static file server |
| `/copyparty` | CopyParty | File sharing |

---

## Custom Docker Images

Three Dockerfiles (in repo root) build rclone+fuse into upstream images:

| Directory | Base Image | Purpose |
|---|---|---|
| `immich-rclone/` | immich-server | Immich with cloud-storage mount support |
| `plex-rclone/` | linuxserver/plex | Plex with rclone fuse entrypoint |
| `deno-rclone/` | denoland/deno | Deno worker with rclone + entrypoint |

All published to `ghcr.io/mnsrulz/`.

---

## Setup Order

### 1. Cluster (k3s)

**Server** (at `192.168.0.30`):
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.30.4+k3s1 sh -
```

**Agent** — generate token on the server, then join:
```bash
# On server:
k3s token generate

# On agent:
curl -sfL https://get.k3s.io | \
  K3S_URL=https://192.168.0.30:6443 \
  K3S_TOKEN=REPLACE_TOKEN \
  INSTALL_K3S_VERSION=v1.30.4+k3s1 sh -
```

> **Note**: Replace `192.168.0.30` with your server IP. Both nodes must run the same k3s version.

### 2. Firewall

Run on **every node** (Alpine/Debian syntax may differ):

```bash
# Install (Alpine)
apk add ip6tables ufw

# K3s API
ufw allow 6443/tcp
# Kubelet
ufw allow 10250/tcp
# Flannel VXLAN overlay (UDP — crucial for pod networking)
ufw allow 8472/udp

ufw enable
ufw status
```

### 3. ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

> **Note**: Uses `stable` manifest. Pin to a release version for reproducibility if desired.

### 4. Argo Workflows

```bash
kubectl create namespace argo
kubectl apply -n argo -f \
  "https://github.com/argoproj/argo-workflows/releases/download/v3.7.6/quick-start-minimal.yaml"
```

### 5. TLS Certificates (local dev)

#### On macOS — generate and trust

```bash
brew install mkcert
mkcert -install
mkcert argocd.local argo.local immich.local resume.local n8n.local \
        s3.local plex.local mzworker.local duckdb.local
```

Install the CA on iPhone:
```bash
cp "$(mkcert -CAROOT)/rootCA.pem" ~/Desktop/
```
Send via AirDrop, then:
1. Settings → Profile Downloaded → Install
2. Settings → General → About → Certificate Trust Settings → toggle ON

Send cert/key to server via croc:
```bash
croc send argocd.local+8.pem argocd.local+8-key.pem
```

#### On Alpine (k3s) — create TLS secret in all namespaces

```bash
for ns in $(sudo kubectl get ns -o name | cut -d/ -f2); do
  sudo kubectl create secret tls wildcard-local-tls \
    --cert=argocd.local+8.pem --key=argocd.local+8-key.pem \
    -n "$ns" --dry-run=client -o yaml | sudo kubectl apply -f -
done
```

#### Renewal

Regenerate on Mac, croc to Alpine, re-run the `for ns` loop above (every 2+ years).

### 6. Secrets

Secrets are created imperatively. Substitute empty values as needed.

```bash
# mediastreamer
kubectl create secret generic mediastreamer \
  --from-literal=LINKS_API_URL='https://user:pass@cachecacheapp'

# mediatcatalogworker
kubectl create secret generic mediacatalogworker \
  --from-literal=PUSHER_APP_KEY='' \
  --from-literal=PLEX_API_TOKEN='' \
  --from-literal=GOOGLE_DRIVE_SERVICE_ACCOUNT_EMAIL='' \
  --from-literal=GOOGLE_DRIVE_JWT_KEY='' \
  --from-literal=LOGTAIL_TOKEN=''

# mzworker
kubectl create secret generic mzworker \
  --from-literal=PUSHER_APP_KEY='' \
  --from-literal=PUSHER_URI='' \
  --from-literal=REDIS_URI='' \
  --from-literal=LOGTAIL_TOKEN='' \
  --from-literal=TURSO_TOKEN='' \
  --from-literal=TURSO_URL=''

# rclone config (for cloud storage mounts)
kubectl create secret generic blob-rclone-conf --from-file=rclone.conf

# SeaweedFS
kubectl create secret generic seaweed-secret \
  --from-literal=SEAWEED_ACCESS_KEY_ID='' \
  --from-literal=SEAWEED_ACCESS_KEY=''

# Immich (if enabled)
kubectl create configmap postgres-config \
  --from-literal=DB_PATH='/home/immichdb'
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD=''
kubectl create secret generic immich-secret \
  --from-literal=JWT_SECRET=''

# Reactive Resume
kubectl create configmap reactiveresumepostgres-config \
  --from-literal=DB_PATH='/home/reactiveresumedb'
kubectl create secret generic reactiveresume-secrets \
  --from-literal=POSTGRES_PASSWORD='' \
  --from-literal=DATABASE_URL='postgresql://reactiveresume:@reactiveresumepostgres:5432/reactiveresume' \
  --from-literal=AUTH_SECRET=''

# Hugging Face
kubectl create secret generic hf-token --from-literal=HF_TOKEN=''

# CloudAMQP
kubectl create secret generic cloudamqp-secret \
  --from-literal=AMQP_URI=''
```

To view or edit an existing secret:
```bash
kubectl edit secret mediacatalogworker
```

### 7. Deploy

The `app01/` directory contains all manifests. Push changes to git and ArgoCD will sync
automatically (in-cluster, pointing at this repo).

---

## CLI Tools

### Helm

```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | \
  sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] \
  https://baltocdn.com/helm/stable/debian/ all main" | \
  sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

### Vault CLI

Follow the [HCP Vault Secrets CLI install guide](https://developer.hashicorp.com/hcp/tutorials/get-started-hcp-vault-secrets/hcp-vault-secrets-install-cli). Use the non-interactive version and `vlt config init` to set the org.

---

## Maintenance

### Resize kubelet mount

If kubelet runs out of space (e.g. for ephemeral volumes):
```bash
mount -o remount,size=15G /var/lib/kubelet
```

### Patch a secret

```bash
kubectl patch secret mzworker \
  -p='{"stringData":{"LOGTAIL_TOKEN":"value"}}'
```

> Note: `LOGTAIL_TOKEN` for `mediastreamer` and `mediacatalogworker` currently share the same
> value. Will be split in the future.

### Remove SSH key for agent

```bash
ssh-keygen -R 192.168.0.60
```

---

## Troubleshooting

### Traefik node selector

First add, then replace (the `nodeSelector` field may not exist initially):
```bash
kubectl -n kube-system patch deployment traefik \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", "value":{"disktype":"SSD"}}]'

kubectl -n kube-system patch deployment traefik \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/nodeSelector", "value":{"disktype":"SSD"}}]'
```

### Argo Server HTTP scheme

If readiness probes fail after TLS setup:
```bash
kubectl -n argo patch deployment argo-server \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env","value":[{"name":"ARGO_BASE_HREF","value":""}, {"name":"ARGO_SECURE","value":"false"}]}]'

kubectl -n argo patch deployment argo-server \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/scheme","value":"HTTP"}]'
```

### Plex custom access URLs

Add this in Plex settings under **Network > Custom server access URLs**:
```
http://192.168.0.30:32400, http://192.168.0.30
```
The first entry is required for Plex Android to display images correctly.

### Verify a secret

```bash
kubectl get secret blob-rclone-conf -o jsonpath="{.data.rclone\.conf}" | base64 --decode
```

### Ingress not syncing

Ingress resources reference the `wildcard-local-tls` secret. If TLS errors appear, ensure the
secret exists in the namespace where the Ingress lives (see [TLS setup](#5-tls-certificates-local-dev)).

---

## Backup

Secrets are created imperatively and **are not tracked in git**. Ensure you:
- Back up `~/.kube/config` and k3s token
- Export secrets regularly: `kubectl get secrets -o yaml > secrets-backup.yaml`
- Store `rootCA.pem` (mkcert CA) safely
- Keep a copy of `rclone.conf` offline
