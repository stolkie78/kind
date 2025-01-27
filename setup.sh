#!/bin/bash

# Exit bij fouten
set -e

# Variabelen
USE_LOCALHOST=true  # Zet op false om een specifiek IP-adres te gebruiken
EXTERNAL_IP=""  # Specifiek IP-adres voor de Ingress Controller
CLUSTER="kind"

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
echo "==========================="
echo "Installeren van kind"
echo "==========================="
if ! command -v kind &> /dev/null; then
  echo "Kind wordt geïnstalleerd..."
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
else
  echo "Kind is al geïnstalleerd."
fi

echo "==========================="
echo "Kind-cluster aanmaken"
echo "==========================="
cat <<EOF | kind create cluster --name ${CLUSTER} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
    - containerPort: 80
      hostPort: 80
    - containerPort: 443
      hostPort: 443
- role: worker
- role: worker
EOF

echo "Kind-cluster aangemaakt."

#echo "=== Stap 3: Nodes labelen voor Ingress ==="
#for node in $(kubectl get nodes -o name); do
#  kubectl label $node ingress-ready=true --overwrite
#done

echo "==========================="
echo "kubectl installeren"
echo "==========================="
if ! command -v kubectl &> /dev/null; then
  echo "Kubectl wordt geïnstalleerd..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
else
  echo "Kubectl is al geïnstalleerd."
fi

echo "==========================="
echo "ArgoCD installeren"
echo "==========================="
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==========================="
echo "Kubernetes Dashboard installeren"
echo "==========================="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin
DASHBOARD_TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-admin)


#kubectl apply -f deployments/argocd/ngnix-ingress.yaml
#kubectl apply -f deployments/argocd/applications.yaml
sleep 60
echo "==========================="
echo "PASSWORDS"
echo "==========================="
echo "Argocd admin: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode)"
echo "Dashboard login token: $DASHBOARD_TOKEN"


