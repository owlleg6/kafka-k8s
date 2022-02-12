terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

    cloudinit = {
      source = "hashicorp/cloudinit"
      version = "~> 2.0"
    }

    tls = {
      source = "hashicorp/tls"
      version = "~> 2.2"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.8.0"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}