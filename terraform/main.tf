# =============================================================================
# Mercury AWS EKS - Main Terraform Configuration
# =============================================================================
#
# This configuration deploys the Mercury platform on AWS EKS.
#
# Deployment Order (Beads):
#   1. Backend Bootstrap (S3 + DynamoDB)
#   2. VPC Infrastructure
#   3. EKS Cluster
#   4. IAM Roles (IRSA)
#   5. Secrets Manager
#   6. S3 Backup Bucket
#   7. CloudWatch Resources
#   8. Route53 DNS (optional)
#
# After Terraform:
#   - Run Flux bootstrap script
#   - Apply Kubernetes manifests via GitOps
#
# =============================================================================

# Local values for common tags and naming
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# Outputs for Quick Reference
# =============================================================================

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}
