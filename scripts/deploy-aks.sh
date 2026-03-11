#!/bin/bash
# =============================================================================
#  deploy-aks.sh  —  Build, push to ACR, and deploy to Azure AKS
#  Usage: ./scripts/deploy-aks.sh
# =============================================================================
set -euo pipefail

# ---------- CONFIGURATION (edit these) ----------
RESOURCE_GROUP="flask-k8s-rg"
LOCATION="eastus"
ACR_NAME="flaskk8sacr"           # Must be globally unique, lowercase, 5-50 chars
CLUSTER_NAME="flask-aks-cluster"
IMAGE_TAG="${IMAGE_TAG:-latest}"
NODE_COUNT=2
NODE_VM_SIZE="Standard_DS2_v2"
# ------------------------------------------------

ACR_URI="${ACR_NAME}.azurecr.io"
IMAGE_FULL="${ACR_URI}/flask-k8s-app:${IMAGE_TAG}"

echo "=============================="
echo " Azure AKS Deployment"
echo "=============================="
echo "Resource Group : $RESOURCE_GROUP"
echo "Location       : $LOCATION"
echo "ACR            : $ACR_NAME"
echo "Cluster        : $CLUSTER_NAME"
echo "Image          : $IMAGE_FULL"
echo ""

# ── STEP 1: Create Resource Group ───────────────────────────────────────────
echo "[1/7] Creating Resource Group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# ── STEP 2: Create ACR ──────────────────────────────────────────────────────
echo "[2/7] Creating Azure Container Registry..."
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic \
  --admin-enabled true 2>/dev/null || echo "ACR already exists, continuing..."

# ── STEP 3: Build & Push to ACR ─────────────────────────────────────────────
echo "[3/7] Building and pushing image to ACR..."
az acr login --name "$ACR_NAME"
docker build -t "flask-k8s-app:$IMAGE_TAG" .
docker tag "flask-k8s-app:$IMAGE_TAG" "$IMAGE_FULL"
docker push "$IMAGE_FULL"

# ── STEP 4: Create AKS cluster ──────────────────────────────────────────────
echo "[4/7] Provisioning AKS cluster (may take ~10 min on first run)..."
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --node-count "$NODE_COUNT" \
  --node-vm-size "$NODE_VM_SIZE" \
  --attach-acr "$ACR_NAME" \
  --enable-addons monitoring \
  --generate-ssh-keys 2>/dev/null || echo "Cluster already exists, continuing..."

# ── STEP 5: Get credentials ──────────────────────────────────────────────────
echo "[5/7] Fetching kubeconfig credentials..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

# ── STEP 6: Attach ACR to AKS (ensures pull permissions) ────────────────────
echo "[6/7] Attaching ACR to AKS..."
az aks update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --attach-acr "$ACR_NAME"

# ── STEP 7: Deploy to Kubernetes ────────────────────────────────────────────
echo "[7/7] Deploying to AKS..."

sed "s|<YOUR_REGISTRY>/flask-k8s-app:latest|$IMAGE_FULL|g" \
  k8s/deployment.yaml | kubectl apply -f -

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

# Wait for rollout
kubectl rollout status deployment/flask-app -n flask-app --timeout=120s

# Show the external LoadBalancer IP
echo ""
echo "=============================="
echo " Deployment complete!"
echo "=============================="
echo "External IP (may take ~2 min to assign):"
kubectl get svc flask-app-service -n flask-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
