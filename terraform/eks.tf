# =============================================================================
# Bead 2: EKS Cluster Deployment
# =============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Bead 2.1: EKS Cluster Core
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # VPC Configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable IRSA (Bead 3 dependency)
  enable_irsa = true

  # Cluster Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate"
        replicaCount = 2
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  # Bead 2.2: Managed Node Group
  eks_managed_node_groups = {
    general = {
      name = "${var.project_name}-node-group"

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Node group defaults
      ami_type       = "AL2023_x86_64_STANDARD"
      disk_size      = 50
      disk_type      = "gp3"
      disk_iops      = 3000
      disk_throughput = 125

      labels = {
        Environment = var.environment
        NodeGroup   = "general"
      }

      tags = {
        Bead = "2"
      }
    }
  }

  # Cluster access
  enable_cluster_creator_admin_permissions = true

  tags = {
    Bead = "2"
  }
}

# =============================================================================
# EBS CSI Driver IRSA Role
# =============================================================================

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi-role"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Bead = "2"
  }
}

# =============================================================================
# Bead 2.3: Cilium CNI (Optional - replaces VPC CNI)
# =============================================================================
# Uncomment to use Cilium instead of VPC CNI
# Note: Requires removing vpc-cni addon above

# resource "helm_release" "cilium" {
#   name       = "cilium"
#   repository = "https://helm.cilium.io/"
#   chart      = "cilium"
#   version    = "1.14.5"
#   namespace  = "kube-system"
#
#   set {
#     name  = "eni.enabled"
#     value = "true"
#   }
#
#   set {
#     name  = "ipam.mode"
#     value = "eni"
#   }
#
#   set {
#     name  = "egressMasqueradeInterfaces"
#     value = "eth0"
#   }
#
#   set {
#     name  = "routingMode"
#     value = "native"
#   }
#
#   depends_on = [module.eks]
# }

# =============================================================================
# EKS Outputs
# =============================================================================

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}
