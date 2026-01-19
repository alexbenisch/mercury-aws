# =============================================================================
# Bead 12: CloudWatch Monitoring IAM
# =============================================================================

# =============================================================================
# IRSA for CloudWatch Agent
# =============================================================================

module "cloudwatch_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-cloudwatch-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "amazon-cloudwatch:cloudwatch-agent",
        "amazon-cloudwatch:fluent-bit"
      ]
    }
  }

  role_policy_arns = {
    cloudwatch_policy = aws_iam_policy.cloudwatch.arn
  }

  tags = {
    Bead = "12"
  }
}

resource "aws_iam_policy" "cloudwatch" {
  name        = "${var.project_name}-cloudwatch"
  description = "Allow CloudWatch agent and Fluent Bit to write metrics and logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/eks/${var.cluster_name}/*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/containerinsights/${var.cluster_name}/*"
        ]
      },
      {
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Bead = "12"
  }
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "eks_containers" {
  name              = "/aws/eks/${var.cluster_name}/containers"
  retention_in_days = 30

  tags = {
    Bead = "12"
  }
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30

  tags = {
    Bead = "12"
  }
}

# =============================================================================
# CloudWatch Outputs
# =============================================================================

output "cloudwatch_role_arn" {
  description = "IAM role ARN for CloudWatch"
  value       = module.cloudwatch_irsa.iam_role_arn
}
