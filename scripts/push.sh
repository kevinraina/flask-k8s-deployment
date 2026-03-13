#!/bin/bash
set -e
set -a; source .env; set +a

ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ECR_REPO"

echo "[1/3] Logging into ECR..."
aws ecr get-login-password --region $AWS_DEFAULT_REGION \
  | docker login --username AWS --password-stdin \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

echo "[2/3] Tagging image..."
docker tag $IMAGE_NAME:$IMAGE_TAG $ECR_URI:$IMAGE_TAG

echo "[3/3] Pushing to ECR..."
docker push $ECR_URI:$IMAGE_TAG

echo "Pushed: $ECR_URI:$IMAGE_TAG"
