# Flask on Kubernetes — AWS EKS Deployment

A production-grade Flask web application containerized with Docker and deployed on **AWS EKS** using Kubernetes. Features a live dashboard with real-time pod stats, auto-scaling, zero-downtime deployments, and a full CI/CD pipeline.

**Live Demo:** `http://a5c3c24051eeb4965ab44cbe475fcdcd-363326008.us-east-1.elb.amazonaws.com`

---

## Project Structure

```
flask-k8s-app/
├── app/
│   ├── app.py              # Flask app factory + dashboard route
│   ├── routes.py           # API blueprints (/health, /ready, /api/stats)
│   ├── config.py           # Configuration from environment variables
│   ├── requirements.txt    # Python dependencies
│   └── templates/
│       └── index.html      # Live dashboard UI
├── k8s/
│   ├── namespace.yaml      # Isolated K8s namespace
│   ├── deployment.yaml     # 2 replicas, rolling updates, liveness/readiness probes
│   ├── service.yaml        # LoadBalancer (port 80 → 5000)
│   ├── hpa.yaml            # Auto-scales 2–10 pods on CPU/memory
│   └── configmap.yaml      # Centralized environment configuration
├── scripts/
│   ├── build.sh            # Build Docker image
│   ├── push.sh             # Push to AWS ECR
│   ├── deploy.sh           # Deploy to EKS
│   └── full-pipeline.sh    # Run all 3 in sequence
├── terraform/
│   └── eks-cluster.tf      # Infrastructure as Code for EKS + VPC
├── .github/
│   └── workflows/
│       └── ci-cd.yml       # GitHub Actions: Build → Test → Push → Deploy
├── Dockerfile              # Multi-stage build, non-root user, Gunicorn
├── docker-compose.yml      # Local development
├── .env.example            # Environment variable template
└── README.md
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Python 3.12 + Flask |
| Web Server | Gunicorn (production WSGI) |
| Containerization | Docker (multi-stage build) |
| Container Registry | AWS ECR |
| Orchestration | Kubernetes on AWS EKS |
| Auto-scaling | Horizontal Pod Autoscaler |
| CI/CD | GitHub Actions |
| Infrastructure | Terraform |

---

## Quick Start — Local

```bash
git clone https://github.com/kevinraina/flask-k8s-deployment.git
cd flask-k8s-deployment

docker compose up --build
# Visit http://localhost:5000
```

---

## Environment Setup

```bash
cp .env.example .env
```

Fill in `.env`:
```
AWS_ACCOUNT_ID=your_account_id
AWS_DEFAULT_REGION=us-east-1
ECR_REPO=flask-k8s-app
IMAGE_NAME=flask-k8s-app
IMAGE_TAG=latest
EKS_CLUSTER=flask-eks-cluster
```

---

## Deploy to AWS EKS

### Prerequisites
- AWS CLI configured (`aws configure`)
- Docker Desktop running
- `kubectl` and `eksctl` installed

### Option A — Automated (one command)
```bash
bash scripts/full-pipeline.sh
```

### Option B — Step by step
```bash
bash scripts/build.sh    # Build Docker image
bash scripts/push.sh     # Push to ECR
bash scripts/deploy.sh   # Deploy to EKS
```

### Option C — Manual
```bash
# Build and push
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
docker build -t flask-k8s-app:latest .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker tag flask-k8s-app:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/flask-k8s-app:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/flask-k8s-app:latest

# Deploy
aws eks update-kubeconfig --region us-east-1 --name flask-eks-cluster
kubectl apply -f k8s/
kubectl set env deployment/flask-app -n flask-app AWS_REGION=us-east-1
```

---

## Kubernetes Features

| Feature | Description |
|---|---|
| Rolling Updates | Zero-downtime deploys (`maxUnavailable: 0`) |
| Liveness Probe | Auto-restarts unhealthy pods (`GET /health`) |
| Readiness Probe | Gates traffic until pod is ready (`GET /ready`) |
| Resource Limits | CPU 100m–500m, Memory 128Mi–256Mi |
| Auto-scaling | HPA scales 2–10 pods at 70% CPU / 80% memory |
| ConfigMap | Centralized environment config for all pods |
| Security | Non-root user (UID 1001) inside container |

---

## CI/CD Pipeline (GitHub Actions)

Triggered on push to `main`:

```
Code Push → Build & Test → Push to ECR → Deploy to EKS
```

Setup GitHub Secrets (repo → Settings → Secrets → Actions):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

---

## Infrastructure as Code (Terraform)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Provisions: VPC, public/private subnets, EKS cluster, managed node group.

---

## Branching Strategy

```
main          → production (auto-deploys via CI/CD)
develop       → integration branch
feature/*     → new features
infra/*       → infrastructure changes
ci/*          → pipeline changes
```

---

## API Endpoints

| Endpoint | Description |
|---|---|
| `GET /` | Live dashboard |
| `GET /api/stats` | JSON: hostname, uptime, requests, cloud |
| `GET /health` | Kubernetes liveness probe |
| `GET /ready` | Kubernetes readiness probe |

---

## Useful Commands

```bash
kubectl get pods -n flask-app
kubectl logs -n flask-app deployment/flask-app
kubectl get hpa -n flask-app
kubectl get svc flask-app-service -n flask-app
kubectl scale deployment flask-app --replicas=5 -n flask-app

# Save costs overnight
eksctl scale nodegroup --cluster flask-eks-cluster --region us-east-1 --name workers2 --nodes 0 --nodes-min 0

# Bring back up
eksctl scale nodegroup --cluster flask-eks-cluster --region us-east-1 --name workers2 --nodes 2 --nodes-min 1
```

---

## Cleanup

```bash
eksctl delete cluster --name flask-eks-cluster --region us-east-1
```

---

## Team
- **Kevin Raina** — Flask app, Docker, AWS EKS deployment, CI/CD
- **Harshal** — Kubernetes manifests, Azure AKS

Cloud Computing Project — March 2026
