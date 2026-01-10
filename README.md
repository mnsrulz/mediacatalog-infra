# mediacatalog-infra

## Setup the argocd
https://argo-cd.readthedocs.io/en/stable/getting_started/
```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Setup vault cli
https://developer.hashicorp.com/hcp/tutorials/get-started-hcp-vault-secrets/hcp-vault-secrets-install-cli

use non interactive version and vlt config init to set the org

## install helm 
https://helm.sh/docs/intro/install/

```
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

## Create secret
```
kubectl create secret generic mediacstreamer --from-literal=LINKS_API_URL='https://uname:pwd@cachecacheapp'

kubectl create secret generic mediacatalogworker --from-literal=PUSHER_APP_KEY='' --from-literal=PLEX_API_TOKEN='' --from-literal=GOOGLE_DRIVE_SERVICE_ACCOUNT_EMAIL='' --from-literal=GOOGLE_DRIVE_JWT_KEY='' --from-literal=LOGTAIL_TOKEN=''
```
## Edit secrets
```
kubectl edit secret mediacatalogworker
```

mediastreamer and mediacatalogworker shares same token for logtail for now. Will replace it in near future.

When setting up `plex`, please make sure to add the following address in the `Network > Custom server access URLs` section. The first one is needed for plex android to display images appropriately

```
http://192.168.0.30:32400, http://192.168.0.30
```

```
kubectl -n kube-system patch deployment traefik \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", "value":{"disktype":"SSD"}}]'

kubectl -n kube-system patch deployment traefik \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/nodeSelector", "value":{"disktype":"SSD"}}]'

-- probably need to set as add first and then replace
kubectl -n argo patch deployment argo-server \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env","value":[{"name":"ARGO_BASE_HREF","value":""}, {"name":"ARGO_SECURE","value":"false"}]}]'

kubectl -n argo patch deployment argo-server \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/scheme","value":"HTTP"}]'

```

## to setup the argo flow
```
kubectl create namespace argo
kubectl apply -n argo -f "https://github.com/argoproj/argo-workflows/releases/download/v3.7.6/quick-start-minimal.yaml"
```

## to add the agent
```
## make sure to install the same k3s version as in the server
## run me from the server to generate token
k3s token generate

## run me from the agent
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.0.30:6443 K3S_TOKEN=REPLACE_TOKEN INSTALL_K3S_VERSION=v1.30.4+k3s1 sh -

```

## to configure firewall (needs to run from server and agent)
```
# install firewall
apk add ip6tables ufw

# Allow K3s API and all necessary ports if they aren't already
ufw allow 6443/tcp
ufw allow 10250/tcp

# Crucial: Allow UDP port 8472 for Flannel VXLAN overlay traffic
ufw allow 8472/udp

# Ensure UFW is enabled and rules applied
ufw enable 
ufw status
```

## configure blob storage secrets
```
kubectl delete secret blob-rclone-conf
kubectl create secret generic blob-rclone-conf --from-file=rclone.conf

# To read the secret back
kubectl get secret blob-rclone-conf -o jsonpath="{.data.rclone\.conf}" | base64 --decode
```

## immich config
```
kubectl create configmap postgres-config --from-literal=DB_PATH='/home/immichdb'
kubectl create secret generic postgres-secret --from-literal=POSTGRES_PASSWORD=''
kubectl create secret generic immich-secret --from-literal=JWT_SECRET=''
```

## seaweed config
```
kubectl create secret generic seaweed-secret --from-literal=SEAWEED_ACCESS_KEY_ID='' --from-literal=SEAWEED_ACCESS_KEY=''
```
