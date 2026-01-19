#!/bin/bash
# =============================================================================
# Mercury AWS Deployment Script
# =============================================================================
# Usage: ./scripts/deploy.sh [bead-number]
# Example: ./scripts/deploy.sh 1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

BEAD="${1:-all}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Mercury AWS Deployment ===${NC}"
echo "Bead: $BEAD"
echo ""

cd "$TERRAFORM_DIR"

case "$BEAD" in
    0|backend)
        echo -e "${YELLOW}=== Bead 0: Bootstrap Terraform Backend ===${NC}"
        echo "This creates the S3 bucket and DynamoDB table for state management."
        echo ""

        # Initialize without backend first
        terraform init -backend=false

        # Apply only backend resources
        terraform apply -target=module.backend

        echo ""
        echo -e "${GREEN}Backend created. Now run:${NC}"
        echo "  terraform init -migrate-state"
        echo "  ./scripts/deploy.sh 1"
        ;;

    1)
        echo -e "${YELLOW}=== Bead 1: AWS Foundation (VPC) ===${NC}"
        terraform init
        terraform apply -target=module.vpc
        ;;

    2)
        echo -e "${YELLOW}=== Bead 2: EKS Cluster ===${NC}"
        terraform apply -target=module.eks -target=module.ebs_csi_irsa_role

        echo ""
        echo -e "${GREEN}EKS cluster created. Configure kubectl:${NC}"
        terraform output bead2_configure_kubectl
        ;;

    3)
        echo -e "${YELLOW}=== Bead 3: IAM & Security ===${NC}"
        terraform apply \
            -target=module.secrets_manager_irsa \
            -target=module.cert_manager_irsa \
            -target=aws_secretsmanager_secret.customer1_db \
            -target=aws_secretsmanager_secret_version.customer1_db \
            -target=aws_iam_policy.secrets_manager_read \
            -target=aws_iam_policy.cert_manager_route53
        ;;

    4|5|6)
        echo -e "${YELLOW}=== Beads 4-6: Kubernetes Components ===${NC}"
        echo "These are deployed via Flux GitOps."
        echo ""
        echo "Run the Flux bootstrap script:"
        echo "  ./scripts/flux-bootstrap.sh"
        ;;

    7)
        echo -e "${YELLOW}=== Bead 7: S3 Backup Infrastructure ===${NC}"
        terraform apply \
            -target=aws_s3_bucket.cnpg_backups \
            -target=aws_s3_bucket_versioning.cnpg_backups \
            -target=aws_s3_bucket_server_side_encryption_configuration.cnpg_backups \
            -target=aws_s3_bucket_public_access_block.cnpg_backups \
            -target=aws_s3_bucket_lifecycle_configuration.cnpg_backups \
            -target=module.cnpg_backup_irsa \
            -target=aws_iam_policy.cnpg_s3_backup
        ;;

    8|9|10)
        echo -e "${YELLOW}=== Beads 8-10: Application Components ===${NC}"
        echo "These are deployed via Flux GitOps."
        echo "Ensure Flux is running and manifests are committed."
        ;;

    11)
        echo -e "${YELLOW}=== Bead 11: DNS & External Access ===${NC}"
        echo "First, get the NLB DNS name:"
        kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
        echo ""
        echo ""
        echo "Then update terraform.tfvars with nlb_dns_name and run:"
        echo "  terraform apply -target=aws_route53_record.customer1"
        ;;

    12)
        echo -e "${YELLOW}=== Bead 12: Monitoring ===${NC}"
        terraform apply \
            -target=module.cloudwatch_irsa \
            -target=aws_iam_policy.cloudwatch \
            -target=aws_cloudwatch_log_group.eks_containers \
            -target=aws_cloudwatch_log_group.eks_cluster
        ;;

    13)
        echo -e "${YELLOW}=== Bead 13: Production Readiness ===${NC}"
        echo "Running full deployment..."
        terraform apply
        ;;

    all)
        echo -e "${YELLOW}=== Full Deployment ===${NC}"
        echo ""
        echo "Recommended deployment order:"
        echo "  1. ./scripts/deploy.sh 0      # Bootstrap backend"
        echo "  2. terraform init -migrate-state"
        echo "  3. ./scripts/deploy.sh 1      # VPC"
        echo "  4. ./scripts/deploy.sh 2      # EKS"
        echo "  5. ./scripts/deploy.sh 3      # IAM"
        echo "  6. ./scripts/deploy.sh 7      # S3 Backup"
        echo "  7. ./scripts/deploy.sh 12     # CloudWatch"
        echo "  8. ./scripts/flux-bootstrap.sh # Flux"
        echo "  9. ./scripts/update-dns.sh    # DNS"
        echo ""
        echo "Or deploy everything at once:"
        echo "  terraform apply"
        ;;

    *)
        echo "Usage: $0 [bead-number|all]"
        echo ""
        echo "Available options:"
        echo "  0/backend - Bootstrap Terraform backend"
        echo "  1         - AWS Foundation (VPC)"
        echo "  2         - EKS Cluster"
        echo "  3         - IAM & Security"
        echo "  4-6       - Kubernetes Components (via Flux)"
        echo "  7         - S3 Backup Infrastructure"
        echo "  8-10      - Application Components (via Flux)"
        echo "  11        - DNS & External Access"
        echo "  12        - Monitoring"
        echo "  13        - Production Readiness (full apply)"
        echo "  all       - Show deployment order"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=== Done ===${NC}"
