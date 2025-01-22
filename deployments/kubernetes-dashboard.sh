#!/bin/bash
kubectl create namespace kubernetes-dashboard
kubectl apply -n kubernetes-dashboard -f kubernetes-dashboard.yaml
kubectl -n kubernetes-dashboard create token admin-user
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
