# Flask App Deployment on AWS EKS using Docker and Kubernetes

A production-ready Flask web application containerized with Docker and deployed on AWS EKS using Kubernetes.

---

## Live URL
```
http://a5c3c24051eeb4965ab44cbe475fcdcd-363326008.us-east-1.elb.amazonaws.com
```

---

## Project Structure
```
flask-k8s-app/
├── app/
│   ├── app.py                  # Flask application
│   ├── requirements.txt        # Python dependencies
│   └── templates/
│       └── index.html          # Dashboard UI
├── k8s/
│   ├── namespace.yaml          # Kubernetes namespace
│   ├── deployment.yaml         # Deployment (2 replicas, rolling updates)
│   ├── service.yaml            # LoadBalancer service
│   └── hpa.yaml                # Horizontal Pod Autoscaler (2-10 pods)
├── scripts/
│   ├── deploy-eks.sh           # AWS EKS deploy script
│   └── deploy-aks.sh           # Azure AKS deploy script
├── Dockerfile                  # Multi-stage Docker build
├── docker-compose.yml          # Local testing
└── README.md
```

---

## Prerequisites

Install these tools:

| Tool | Install Command |
|------|----------------|
| Docker Desktop | https://docker.com |
| kubectl | `choco install kubernetes-cli` |
| AWS CLI | `choco install awscli` |
| eksctl | `choco install eksctl` |

---

## Step 1 — Run Locally with Docker

```bash
docker compose up --build
```

Open browser at: http://localhost:5000

---

## Step 2 — Configure AWS

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region: us-east-1, Output: json
```

---

## Step 3 — Create ECR Repository and Push Image

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

# Create ECR repo
aws ecr create-repository --repository-name flask-k8s-app --region $AWS_REGION

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push
docker build -t flask-k8s-app:latest .
docker tag flask-k8s-app:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/flask-k8s-app:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/flask-k8s-app:latest
```

---

## Step 4 — Create EKS Cluster

```bash
eksctl create cluster \
  --name flask-eks-cluster \
  --region us-east-1 \
  --nodegroup-name workers2 \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

Takes ~15 minutes.

---

## Step 5 — Connect kubectl to EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name flask-eks-cluster
```

---

## Step 6 — Update Image in deployment.yaml

Open `k8s/deployment.yaml` and replace this line:
```yaml
image: <YOUR_REGISTRY>/flask-k8s-app:latest
```
With your actual ECR URI:
```yaml
image: <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/flask-k8s-app:latest
```

---

## Step 7 — Deploy to Kubernetes

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
```

Set cloud provider label:
```bash
kubectl set env deployment/flask-app -n flask-app AWS_REGION=us-east-1
```

---

## Step 8 — Get Live URL

```bash
kubectl get svc flask-app-service -n flask-app
```

Copy the EXTERNAL-IP and open in browser.

---

## Useful Commands

```bash
# Check pods
kubectl get pods -n flask-app

# Check logs
kubectl logs -n flask-app deployment/flask-app

# Check autoscaler
kubectl get hpa -n flask-app

# Scale nodes down (save cost)
eksctl scale nodegroup --cluster flask-eks-cluster --region us-east-1 --name workers2 --nodes 0

# Scale nodes back up
eksctl scale nodegroup --cluster flask-eks-cluster --region us-east-1 --name workers2 --nodes 2
```

---

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Live dashboard |
| `/api/stats` | JSON stats |
| `/health` | Liveness probe |
| `/ready` | Readiness probe |

---

## Architecture

```
Internet → AWS Load Balancer → K8s Service → Flask Pods (2-10) → HPA Auto-scales
```

---

## Cleanup (avoid charges)

```bash
eksctl delete cluster --name flask-eks-cluster --region us-east-1
```
