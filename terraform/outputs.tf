# =============================================================================
# Terraform Outputs - All Beads
# =============================================================================

# =============================================================================
# Bead 1: VPC Outputs
# =============================================================================
output "bead1_vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# =============================================================================
# Bead 2: EKS Outputs
# =============================================================================
output "bead2_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "bead2_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "bead2_configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

# =============================================================================
# Bead 3: IAM Outputs
# =============================================================================
output "bead3_secrets_manager_role_arn" {
  description = "IAM role ARN for Secrets Manager access"
  value       = module.secrets_manager_irsa.iam_role_arn
}

output "bead3_cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager"
  value       = module.cert_manager_irsa.iam_role_arn
}

# =============================================================================
# Bead 7: S3 Backup Outputs
# =============================================================================
output "bead7_backup_bucket" {
  description = "S3 bucket for CNPG backups"
  value       = aws_s3_bucket.cnpg_backups.id
}

output "bead7_cnpg_backup_role_arn" {
  description = "IAM role ARN for CNPG S3 backup"
  value       = module.cnpg_backup_irsa.iam_role_arn
}

# =============================================================================
# Bead 12: CloudWatch Outputs
# =============================================================================
output "bead12_cloudwatch_role_arn" {
  description = "IAM role ARN for CloudWatch"
  value       = module.cloudwatch_irsa.iam_role_arn
}

# =============================================================================
# Summary for Variable Substitution
# =============================================================================
output "flux_variable_substitutions" {
  description = "Values to substitute in Flux manifests"
  value = {
    SECRETS_MANAGER_ROLE_ARN = module.secrets_manager_irsa.iam_role_arn
    CERT_MANAGER_ROLE_ARN    = module.cert_manager_irsa.iam_role_arn
    CNPG_BACKUP_ROLE_ARN     = module.cnpg_backup_irsa.iam_role_arn
    CLOUDWATCH_ROLE_ARN      = module.cloudwatch_irsa.iam_role_arn
    S3_BACKUP_BUCKET         = aws_s3_bucket.cnpg_backups.id
  }
  sensitive = false
}
