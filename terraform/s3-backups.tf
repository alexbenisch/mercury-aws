# =============================================================================
# Bead 7: S3 Backup Infrastructure for CloudNativePG
# =============================================================================

# =============================================================================
# Bead 7.1: S3 Bucket for Database Backups
# =============================================================================

resource "aws_s3_bucket" "cnpg_backups" {
  bucket = "${var.project_name}-cnpg-backups-${var.environment}"

  tags = {
    Bead        = "7"
    Purpose     = "CloudNativePG Backups"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    filter {
      prefix = ""
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    filter {
      prefix = "archive/"
    }
  }
}

# =============================================================================
# Bead 7.2: IRSA for CloudNativePG S3 Access
# =============================================================================

module "cnpg_backup_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-cnpg-backup-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["customer1:customer1-db"]
    }
  }

  role_policy_arns = {
    s3_backup_policy = aws_iam_policy.cnpg_s3_backup.arn
  }

  tags = {
    Bead = "7"
  }
}

resource "aws_iam_policy" "cnpg_s3_backup" {
  name        = "${var.project_name}-cnpg-s3-backup"
  description = "Allow CloudNativePG to backup/restore from S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.cnpg_backups.arn
      },
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.cnpg_backups.arn}/*"
      }
    ]
  })

  tags = {
    Bead = "7"
  }
}

# =============================================================================
# S3 Backup Outputs
# =============================================================================

output "cnpg_backup_bucket_name" {
  description = "S3 bucket name for CNPG backups"
  value       = aws_s3_bucket.cnpg_backups.id
}

output "cnpg_backup_bucket_arn" {
  description = "S3 bucket ARN for CNPG backups"
  value       = aws_s3_bucket.cnpg_backups.arn
}

output "cnpg_backup_role_arn" {
  description = "IAM role ARN for CNPG S3 backup access"
  value       = module.cnpg_backup_irsa.iam_role_arn
}
