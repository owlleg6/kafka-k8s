locals {
  name            = "ex-${replace(basename(path.cwd), "_", "-")}"
  cluster_version = "1.21"
  region          = var.aws_region

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }
}

# Networking
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.12.0"

  name = "kafka-k8s-vpc"
  cidr = var.cidr

  azs = ["eu-central-1b", "eu-central-1c"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false

  default_vpc_enable_dns_hostnames = true
  default_vpc_enable_dns_support   = true

  tags = {
    Owner       = "Oleh_Mykolaishyn"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "kafka-k8s-vpc"
  }
}

# EKS cluter
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.5.1"

  cluster_name                    = local.name
  cluster_version                 = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets


  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all       = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    disk_size              = 30
    instance_types         = ["t2.medium"]
    vpc_security_group_ids = [aws_security_group.additional.id]
  }

  eks_managed_node_groups = {
    #blue  = {}
    green = {
      min_size     = 1
      max_size     = 5
      desired_size = 3

      instance_types = ["t2.medium"]
      capacity_type  = "SPOT"
      labels         = {
        Environment = "test"
        GithubRepo  = "terraform-aws-eks"
        GithubOrg   = "terraform-aws-modules"
      }

      taints = {
        dedicated = {
          key    = "dedicated"
          value  = "gpuGroup"
          effect = "NO_SCHEDULE"
        }
      }

      update_config = {
        max_unavailable_percentage = 50 # or set `max_unavailable`
      }

      tags = {
        ExtraTag = "example"
      }
    }
  }
}
# Additional resources

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}


data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_id
}

locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters        = [
      {
        name    = module.eks.cluster_id
        cluster = {
          certificate-authority-data = module.eks.cluster_certificate_authority_data
          server                     = module.eks.cluster_endpoint
        }
      }
    ]
    contexts        = [
      {
        name    = "terraform"
        context = {
          cluster = module.eks.cluster_id
          user    = "terraform"
        }
      }
    ]
    users           = [
      {
        name = "terraform"
        user = {
          token = data.aws_eks_cluster_auth.this.token
        }
      }
    ]
  })
}

resource "aws_security_group" "additional" {
    name_prefix = "${local.name}-additional"
    vpc_id      = module.vpc.vpc_id

    ingress {
      from_port = 22
      to_port   = 22
      protocol  = "tcp"
      cidr_blocks = [
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
      ]
    }

    tags = local.tags
  }

resource "helm_release" "helm-kafka" {
  name             = "confluentinc"
  namespace        = "confluence"
  repository       = "https://confluentinc.github.io/cp-helm-charts/"
  chart            = "cp-helm-charts"
  version          = "0.6.0"
  create_namespace = true

  timeout = 600


  depends_on = [module.eks]
}