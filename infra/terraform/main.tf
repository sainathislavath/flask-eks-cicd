terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source         = "terraform-aws-modules/vpc/aws"
  version        = "~> 5.1"
  name           = "eks-vpc"
  cidr           = "10.0.0.0/16"
  azs            = ["us-west-2a", "us-west-2b"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # Enable auto-assign public IP on launch for public subnets (required for EKS nodes)
  map_public_ip_on_launch = true
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.37"
  cluster_name    = "flask-eks-cluster-dev" # Changed to avoid name conflict
  cluster_version = "1.29"
  subnet_ids      = module.vpc.public_subnets
  vpc_id          = module.vpc.vpc_id

  # Disable automatic KMS key creation to avoid AccessDenied
  create_kms_key            = false
  cluster_encryption_config = {}

  # Enable public endpoint access for kubectl from local machine
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IAM user/role access to cluster
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["t3.medium"]
    }
  }
}

resource "aws_ecr_repository" "flask" {
  name = "flask-app"
}
