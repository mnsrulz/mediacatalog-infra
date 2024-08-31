# mediacatalog-infra


Setup vault cli
https://developer.hashicorp.com/hcp/tutorials/get-started-hcp-vault-secrets/hcp-vault-secrets-install-cli
use non interactive version and vlt config init to set the org

install helm using https://helm.sh/docs/intro/install/
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

create secret
kubectl create secret generic mediacstreamer --from-literal=LINKS_API_URL='https://uname:pwd@mediacatalogcache.netlify.app'

kubectl create secret generic mediacatalogworker --from-literal=PUSHER_APP_KEY='' --from-literal=PLEX_API_TOKEN='' --from-literal=GOOGLE_DRIVE_SERVICE_ACCOUNT_EMAIL='' --from-literal=GOOGLE_DRIVE_JWT_KEY='' --from-literal=LOGTAIL_TOKEN=''

#to edit secrets
kubectl edit secret mediacatalogworker

mediastreamer and mediacatalogworker shares same token for logtail for now. Will replace it in near future.