#!/bin/bash
#
# This script creates a kind cluster
#

# Exit bij fouten
set -e

# Variabelen
USE_LOCALHOST=true  # Zet op false om een specifiek IP-adres te gebruiken
EXTERNAL_IP=""  # Specifiek IP-adres voor de Ingress Controller
CLUSTER="cluster-1" # Zo heet het cluster
ARGOCD_REPO="https://github.com/stolkie78/argocd-kind" # Hier staan de deployments voor argocd
ARGOCD_PATH="kubernetes/" #Relatieve pad in argocd voor het zoeken van deployment files

function stop_message() {
  echo "==========================="
  echo "CLUSTER ${CLUSTER} CONFIGURED"
  echo "==========================="
  echo "Delete the cluster with: kind delete cluster -n ${CLUSTER}"
  exit 0
}

# Functie om te wachten op een resource
wait_for_resource() {
  local namespace=$1
  local selector=$2
  local timeout=$3

  echo "Wachten op resources in namespace $namespace met selector $selector..."
  for i in {1..5}; do
    if kubectl wait --namespace "$namespace" \
      --for=condition=ready pod \
      --selector="$selector" \
      --timeout="$timeout"; then
      echo "Resources in namespace $namespace zijn actief!"
      return 0
    else
      echo "Resources niet actief. Poging $i van 5..."
      sleep 30
    fi
  done
  echo "Fout: Resources in namespace $namespace konden niet worden geactiveerd."
  exit 1
}

# Stop als er al een cluster is
kind get clusters | grep -q ${CLUSTER} && stop_message

echo "==========================="
echo "Kind-cluster aanmaken"
echo "==========================="
echo "kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER}
nodes:
- role: control-plane
  extraPortMappings:
    - containerPort: 80
      hostPort: 80
    - containerPort: 443
      hostPort: 443
- role: worker
- role: worker
" > kind.yaml

echo "Kind-cluster config aangemaakt."
kind create cluster --config kind.yaml

echo "==========================="
echo "Ingress Controller installeren"
echo "==========================="
echo "- Nodes labelen voor Ingress"
for node in $(kubectl get nodes -o name); do
  kubectl label $node ingress-ready=true --overwrite
done

echo "==========================="
echo "Ingress Controller installeren"
echo "==========================="
echo "- Nodes labelen voor Ingress"
for node in $(kubectl get nodes -o name); do
  kubectl label $node ingress-ready=true --overwrite
done

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
wait_for_resource ingress-nginx "app.kubernetes.io/component=controller" "120s"
echo "- Configureren van Ingress Controller"
if [ "$USE_LOCALHOST" = true ]; then
  echo "Ingress Controller gebruikt localhost."
else
  echo "Ingress Controller wordt geconfigureerd met extern IP: $EXTERNAL_IP"
  kubectl patch deployment -n ingress-nginx ingress-nginx-controller --type=json \
    -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--publish-status-address='$EXTERNAL_IP'"}]'
  kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
fi

EXTERNAL_ADDRESS=$([ "$USE_LOCALHOST" = true ] && echo "localhost" || echo "$EXTERNAL_IP")
ARGOPASS=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode)
sleep 60

echo "==========================="
echo "ArgoCD installeren"
echo "==========================="
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f bootstrap/argocd/nginx-ingress.yaml

echo "=== ARGOCD Repo toevoegen ==="
wait_for_resource "argocd" "app.kubernetes.io/name=argocd-server" "120s"
sleep 60
argocd login argocd.local --grpc-web --insecure --username admin --password "${ARGOPASS}"
argocd repo add ${ARGOCD_REPO} --name kind-demo
argocd app create config --repo "${ARGOCD_REPO}" --path "${ARGOCD_PATH}" --dest-server https://kubernetes.default.svc --dest-namespace argocd --sync-policy automated --auto-prune --self-heal --directory-recurse

echo "==========================="
echo "PASSWORDS"
echo "==========================="
echo "Argocd admin: ${ARGOPASS}"
echo "Dashboard login token: $DASHBOARD_TOKEN"

stop_message
