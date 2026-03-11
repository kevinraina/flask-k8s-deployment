#!/bin/bash
# =============================================================================
#  deploy-eks.sh  —  Build, push to ECR, and deploy to AWS EKS
#  Usage: ./scripts/deploy-eks.sh
# =============================================================================
set -euo pipefail

# ---------- CONFIGURATION (edit these) ----------
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="flask-k8s-app"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CLUSTER_NAME="flask-eks-cluster"
CLUSTER_NODE_TYPE="t3.medium"
CLUSTER_NODES=2
# ------------------------------------------------

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "=============================="
echo " AWS EKS Deployment"
echo "=============================="
echo "Account : $AWS_ACCOUNT_ID"
echo "Region  : $AWS_REGION"
echo "Cluster : $CLUSTER_NAME"
echo "Image   : $ECR_URI:$IMAGE_TAG"
echo ""

# ── STEP 1: Create ECR repository (skip if it exists) ──────────────────────
echo "[1/6] Creating ECR repository..."
aws ecr describe-repositories --repository-names "$ECR_REPO" \
    --region "$AWS_REGION" 2>/dev/null || \
  aws ecr create-repository \
    --repository-name "$ECR_REPO" \
    --region "$AWS_REGION" \
    --image-scanning-configuration scanOnPush=true

# ── STEP 2: Build Docker image ──────────────────────────────────────────────
echo "[2/6] Building Docker image..."
docker build -t "$ECR_REPO:$IMAGE_TAG" .

# ── STEP 3: Push to ECR ─────────────────────────────────────────────────────
echo "[3/6] Authenticating and pushing to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin \
    "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker tag "$ECR_REPO:$IMAGE_TAG" "$ECR_URI:$IMAGE_TAG"
docker push "$ECR_URI:$IMAGE_TAG"

# ── STEP 4: Create EKS cluster (skip if it exists) ──────────────────────────
echo "[4/6] Provisioning EKS cluster (may take ~15 min on first run)..."
if ! eksctl get cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" 2>/dev/null; then
  eksctl create cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --nodegroup-name standard-workers \
    --node-type "$CLUSTER_NODE_TYPE" \
    --nodes "$CLUSTER_NODES" \
    --nodes-min 1 \
    --nodes-max 4 \
    --managed
fi

# ── STEP 5: Update kubeconfig ────────────────────────────────────────────────
echo "[5/6] Updating kubeconfig..."
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

# ── STEP 6: Deploy to Kubernetes ────────────────────────────────────────────
echo "[6/6] Deploying to EKS..."

# Patch the image placeholder in deployment.yaml and apply
sed "s|<YOUR_REGISTRY>/flask-k8s-app:latest|$ECR_URI:$IMAGE_TAG|g" \
  k8s/deployment.yaml | kubectl apply -f -

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

# Wait for rollout
kubectl rollout status deployment/flask-app -n flask-app --timeout=120s

# Show the external LoadBalancer URL
echo ""
echo "=============================="
echo " Deployment complete!"
echo "=============================="
echo "External URL (may take ~2 min to assign):"
kubectl get svc flask-app-service -n flask-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
