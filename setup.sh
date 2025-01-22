#!/bin/bash

# Exit bij fouten
set -e

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

echo "=== Stap 1: Installeren van kind ==="
if ! command -v kind &> /dev/null; then
  echo "Kind wordt geïnstalleerd..."
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
else
  echo "Kind is al geïnstalleerd."
fi

echo "=== Stap 2: Kind-cluster aanmaken ==="
cat <<EOF | kind create cluster --name bryxx-demo --config=-
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

echo "=== Stap 3: kubectl installeren ==="
if ! command -v kubectl &> /dev/null; then
  echo "Kubectl wordt geïnstalleerd..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
else
  echo "Kubectl is al geïnstalleerd."
fi

echo "=== Stap 4: ArgoCD installeren ==="
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Stap 5: Kubernetes Dashboard installeren ==="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin
DASHBOARD_TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-admin)

echo "Dashboard login token: $DASHBOARD_TOKEN"

echo "=== Stap 6: Ingress Controller installeren ==="

for node in $(kubectl get nodes -o name); do
  kubectl label $node ingress-ready=true --overwrite
done
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

wait_for_resource ingress-nginx "app.kubernetes.io/component=controller" "120s"

echo "=== Stap 7: Prometheus en Grafana installeren ==="
if ! command -v helm &> /dev/null; then
  echo "Helm wordt geïnstalleerd..."
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
else
  echo "Helm is al geïnstalleerd."
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

echo "=== Stap 8: Toegang configureren ==="
ARGO_PORT=$(kubectl -n argocd get svc argocd-server -o=jsonpath='{.spec.ports[0].nodePort}')
DASHBOARD_PORT=$(kubectl -n kubernetes-dashboard get svc kubernetes-dashboard -o=jsonpath='{.spec.ports[0].nodePort}')

echo "=== Toegang Informatie ==="
echo "ArgoCD: http://localhost:$ARGO_PORT"
echo "Dashboard: http://localhost:$DASHBOARD_PORT"
echo "Prometheus: http://localhost:80 (via Ingress)"
echo "Grafana: http://localhost:80 (via Ingress)"

echo "=== Installatie voltooid! ==="
