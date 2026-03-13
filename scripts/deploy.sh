#!/bin/bash
set -e
set -a; source .env; set +a

echo "[1/3] Updating kubeconfig..."
aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name $EKS_CLUSTER

echo "[2/3] Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

echo "[3/3] Waiting for rollout..."
kubectl rollout status deployment/flask-app -n flask-app

echo ""
echo "Deployment complete! External URL:"
kubectl get svc flask-app-service -n flask-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
