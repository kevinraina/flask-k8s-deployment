#!/bin/bash
set -e
set -a; source .env; set +a

echo "[1/1] Building Docker image: $IMAGE_NAME:$IMAGE_TAG"
docker build -t $IMAGE_NAME:$IMAGE_TAG .
echo "Build complete: $IMAGE_NAME:$IMAGE_TAG"
