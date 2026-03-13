provider "aws" {
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "flask-eks-cluster"
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.cluster_name}-vpc"
  cidr = "192.168.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  public_subnets  = ["192.168.0.0/19", "192.168.32.0/19"]
  private_subnets = ["192.168.64.0/19", "192.168.96.0/19"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  eks_managed_node_groups = {
    workers = {
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 4
      desired_size   = 2
    }
  }

  tags = {
    Project = "flask-k8s-app"
  }
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
