# =============================================================================
# Bead 3: IAM & Security Foundation - Secrets Manager
# =============================================================================

# =============================================================================
# Bead 3.2: Secrets Manager Secrets
# =============================================================================

resource "aws_secretsmanager_secret" "customer1_db" {
  name        = "customer1-db-credentials"
  description = "Database credentials for customer1"

  tags = {
    Bead      = "3"
    Customer  = "customer1"
  }
}

resource "aws_secretsmanager_secret_version" "customer1_db" {
  secret_id = aws_secretsmanager_secret.customer1_db.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

# =============================================================================
# Bead 3.1 & 3.2: IRSA for Secrets Manager Access
# =============================================================================

module "secrets_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-secrets-manager-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["customer1:default", "customer1:customer1-sa"]
    }
  }

  role_policy_arns = {
    secrets_policy = aws_iam_policy.secrets_manager_read.arn
  }

  tags = {
    Bead = "3"
  }
}

resource "aws_iam_policy" "secrets_manager_read" {
  name        = "${var.project_name}-secrets-manager-read"
  description = "Allow reading secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetSecretValue"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.customer1_db.arn
        ]
      }
    ]
  })

  tags = {
    Bead = "3"
  }
}

# =============================================================================
# cert-manager IRSA for Route53 DNS Challenge (Bead 6 dependency)
# =============================================================================

module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-cert-manager-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

  role_policy_arns = {
    route53_policy = aws_iam_policy.cert_manager_route53.arn
  }

  tags = {
    Bead = "3"
  }
}

resource "aws_iam_policy" "cert_manager_route53" {
  name        = "${var.project_name}-cert-manager-route53"
  description = "Allow cert-manager to manage Route53 records for DNS challenge"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ChangeResourceRecordSets"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Sid    = "ListHostedZones"
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      },
      {
        Sid    = "GetChange"
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = "arn:aws:route53:::change/*"
      }
    ]
  })

  tags = {
    Bead = "3"
  }
}

# =============================================================================
# Secrets Manager Outputs
# =============================================================================

output "secrets_manager_role_arn" {
  description = "IAM role ARN for Secrets Manager access"
  value       = module.secrets_manager_irsa.iam_role_arn
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager"
  value       = module.cert_manager_irsa.iam_role_arn
}

output "customer1_secret_arn" {
  description = "ARN of customer1 database secret"
  value       = aws_secretsmanager_secret.customer1_db.arn
}
