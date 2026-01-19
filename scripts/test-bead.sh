#!/bin/bash
# =============================================================================
# Bead Testing Script
# =============================================================================
# Usage: ./scripts/test-bead.sh <bead-number>
# Example: ./scripts/test-bead.sh 2

set -euo pipefail

BEAD="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
}

check_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    FAILED=1
}

FAILED=0

case "$BEAD" in
    1)
        echo -e "${YELLOW}=== Testing Bead 1: AWS Foundation ===${NC}"

        echo "Testing VPC..."
        VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=mercury-vpc-*" --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
        if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
            check_pass "VPC exists: $VPC_ID"
        else
            check_fail "VPC not found"
        fi

        echo "Testing Subnets..."
        SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "length(Subnets)" --output text 2>/dev/null || echo "0")
        if [ "$SUBNET_COUNT" -ge 6 ]; then
            check_pass "Subnets exist: $SUBNET_COUNT subnets"
        else
            check_fail "Expected 6 subnets, found $SUBNET_COUNT"
        fi

        echo "Testing S3 Backend..."
        if aws s3api head-bucket --bucket mercury-terraform-state 2>/dev/null; then
            check_pass "Terraform state bucket exists"
        else
            check_fail "Terraform state bucket not found"
        fi
        ;;

    2)
        echo -e "${YELLOW}=== Testing Bead 2: EKS Cluster ===${NC}"

        echo "Testing EKS Cluster..."
        CLUSTER_STATUS=$(aws eks describe-cluster --name mercury-eks-staging --query "cluster.status" --output text 2>/dev/null || echo "")
        if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
            check_pass "EKS cluster is ACTIVE"
        else
            check_fail "EKS cluster status: $CLUSTER_STATUS"
        fi

        echo "Testing kubectl connectivity..."
        if kubectl cluster-info &>/dev/null; then
            check_pass "kubectl connected to cluster"
        else
            check_fail "kubectl cannot connect to cluster"
        fi

        echo "Testing nodes..."
        NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$NODE_COUNT" -ge 2 ]; then
            check_pass "Nodes ready: $NODE_COUNT"
        else
            check_fail "Expected at least 2 nodes, found $NODE_COUNT"
        fi
        ;;

    3)
        echo -e "${YELLOW}=== Testing Bead 3: IAM & Security ===${NC}"

        echo "Testing OIDC Provider..."
        OIDC=$(aws eks describe-cluster --name mercury-eks-staging --query "cluster.identity.oidc.issuer" --output text 2>/dev/null || echo "")
        if [ -n "$OIDC" ]; then
            check_pass "OIDC provider configured"
        else
            check_fail "OIDC provider not found"
        fi

        echo "Testing Secrets Manager secret..."
        if aws secretsmanager describe-secret --secret-id customer1-db-credentials &>/dev/null; then
            check_pass "customer1-db-credentials secret exists"
        else
            check_fail "customer1-db-credentials secret not found"
        fi
        ;;

    4)
        echo -e "${YELLOW}=== Testing Bead 4: Secrets Store CSI ===${NC}"

        echo "Testing CSI Driver pods..."
        CSI_PODS=$(kubectl get pods -n kube-system -l app=secrets-store-csi-driver --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$CSI_PODS" -gt 0 ]; then
            check_pass "CSI Driver pods running: $CSI_PODS"
        else
            check_fail "CSI Driver pods not running"
        fi

        echo "Testing AWS Provider pods..."
        PROVIDER_PODS=$(kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$PROVIDER_PODS" -gt 0 ]; then
            check_pass "AWS Provider pods running: $PROVIDER_PODS"
        else
            check_fail "AWS Provider pods not running"
        fi
        ;;

    5)
        echo -e "${YELLOW}=== Testing Bead 5: Flux CD ===${NC}"

        echo "Testing Flux installation..."
        if flux check &>/dev/null; then
            check_pass "Flux is healthy"
        else
            check_fail "Flux check failed"
        fi

        echo "Testing GitRepository..."
        GIT_STATUS=$(flux get sources git flux-system -o json 2>/dev/null | jq -r '.[-1].status.conditions[-1].status' || echo "")
        if [ "$GIT_STATUS" == "True" ]; then
            check_pass "GitRepository is ready"
        else
            check_fail "GitRepository not ready"
        fi
        ;;

    6)
        echo -e "${YELLOW}=== Testing Bead 6: Infrastructure Controllers ===${NC}"

        echo "Testing Traefik..."
        TRAEFIK_STATUS=$(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$TRAEFIK_STATUS" -gt 0 ]; then
            check_pass "Traefik pods running"
        else
            check_fail "Traefik pods not running"
        fi

        echo "Testing NLB..."
        NLB_DNS=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$NLB_DNS" ]; then
            check_pass "NLB provisioned: $NLB_DNS"
        else
            check_fail "NLB not provisioned"
        fi

        echo "Testing cert-manager..."
        CM_STATUS=$(kubectl get pods -n cert-manager -l app.kubernetes.io/name=cert-manager --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$CM_STATUS" -gt 0 ]; then
            check_pass "cert-manager pods running"
        else
            check_fail "cert-manager pods not running"
        fi

        echo "Testing CloudNativePG..."
        CNPG_STATUS=$(kubectl get pods -n cnpg-system --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$CNPG_STATUS" -gt 0 ]; then
            check_pass "CloudNativePG operator running"
        else
            check_fail "CloudNativePG operator not running"
        fi
        ;;

    7)
        echo -e "${YELLOW}=== Testing Bead 7: S3 Backup ===${NC}"

        echo "Testing S3 bucket..."
        if aws s3api head-bucket --bucket mercury-cnpg-backups-staging 2>/dev/null; then
            check_pass "Backup bucket exists"
        else
            check_fail "Backup bucket not found"
        fi

        echo "Testing bucket versioning..."
        VERSIONING=$(aws s3api get-bucket-versioning --bucket mercury-cnpg-backups-staging --query "Status" --output text 2>/dev/null || echo "")
        if [ "$VERSIONING" == "Enabled" ]; then
            check_pass "Bucket versioning enabled"
        else
            check_fail "Bucket versioning not enabled"
        fi
        ;;

    8)
        echo -e "${YELLOW}=== Testing Bead 8: Customer1 Namespace ===${NC}"

        echo "Testing namespace..."
        if kubectl get ns customer1 &>/dev/null; then
            check_pass "customer1 namespace exists"
        else
            check_fail "customer1 namespace not found"
        fi

        echo "Testing service account..."
        SA_ARN=$(kubectl get sa customer1-sa -n customer1 -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
        if [ -n "$SA_ARN" ]; then
            check_pass "Service account has IRSA annotation"
        else
            check_fail "Service account missing IRSA annotation"
        fi

        echo "Testing SecretProviderClass..."
        if kubectl get secretproviderclass customer1-secrets -n customer1 &>/dev/null; then
            check_pass "SecretProviderClass exists"
        else
            check_fail "SecretProviderClass not found"
        fi
        ;;

    9)
        echo -e "${YELLOW}=== Testing Bead 9: PostgreSQL Cluster ===${NC}"

        echo "Testing PostgreSQL cluster..."
        PG_STATUS=$(kubectl get cluster customer1-db -n customer1 -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$PG_STATUS" == "Cluster in healthy state" ]; then
            check_pass "PostgreSQL cluster healthy"
        else
            check_fail "PostgreSQL cluster status: $PG_STATUS"
        fi

        echo "Testing PostgreSQL pods..."
        PG_PODS=$(kubectl get pods -n customer1 -l cnpg.io/cluster=customer1-db --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$PG_PODS" -ge 3 ]; then
            check_pass "PostgreSQL pods running: $PG_PODS"
        else
            check_fail "Expected 3 PostgreSQL pods, found $PG_PODS"
        fi
        ;;

    10)
        echo -e "${YELLOW}=== Testing Bead 10: Application Deployment ===${NC}"

        echo "Testing n8n deployment..."
        N8N_STATUS=$(kubectl get deploy customer1-n8n -n customer1 -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
        if [ "$N8N_STATUS" -ge 1 ]; then
            check_pass "n8n deployment available"
        else
            check_fail "n8n deployment not available"
        fi

        echo "Testing TLS certificate..."
        CERT_STATUS=$(kubectl get certificate customer1-tls -n customer1 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
        if [ "$CERT_STATUS" == "True" ]; then
            check_pass "TLS certificate ready"
        else
            check_fail "TLS certificate not ready"
        fi
        ;;

    11)
        echo -e "${YELLOW}=== Testing Bead 11: DNS & External Access ===${NC}"

        echo "Testing DNS resolution..."
        DNS_RESULT=$(dig +short customer1.mercury.kubetest.uk 2>/dev/null || echo "")
        if [ -n "$DNS_RESULT" ]; then
            check_pass "DNS resolves: $DNS_RESULT"
        else
            check_fail "DNS does not resolve"
        fi

        echo "Testing HTTPS access..."
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://customer1.mercury.kubetest.uk/healthz 2>/dev/null || echo "000")
        if [ "$HTTP_STATUS" == "200" ]; then
            check_pass "HTTPS returns 200"
        else
            check_fail "HTTPS returns $HTTP_STATUS"
        fi
        ;;

    12)
        echo -e "${YELLOW}=== Testing Bead 12: Monitoring ===${NC}"

        echo "Testing CloudWatch agent..."
        CW_PODS=$(kubectl get pods -n amazon-cloudwatch -l app.kubernetes.io/name=aws-cloudwatch-metrics --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$CW_PODS" -gt 0 ]; then
            check_pass "CloudWatch agent running"
        else
            check_fail "CloudWatch agent not running"
        fi

        echo "Testing Fluent Bit..."
        FB_PODS=$(kubectl get pods -n amazon-cloudwatch -l app.kubernetes.io/name=aws-for-fluent-bit --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$FB_PODS" -gt 0 ]; then
            check_pass "Fluent Bit running"
        else
            check_fail "Fluent Bit not running"
        fi
        ;;

    13)
        echo -e "${YELLOW}=== Testing Bead 13: Production Readiness ===${NC}"

        echo "Running all previous bead tests..."
        for i in {1..12}; do
            echo ""
            $0 $i
        done
        ;;

    *)
        echo "Usage: $0 <bead-number>"
        echo "Available beads: 1-13"
        echo ""
        echo "  1  - AWS Foundation (VPC, S3 Backend)"
        echo "  2  - EKS Cluster"
        echo "  3  - IAM & Security"
        echo "  4  - Secrets Store CSI"
        echo "  5  - Flux CD"
        echo "  6  - Infrastructure Controllers"
        echo "  7  - S3 Backup"
        echo "  8  - Customer1 Namespace"
        echo "  9  - PostgreSQL Cluster"
        echo "  10 - Application Deployment"
        echo "  11 - DNS & External Access"
        echo "  12 - Monitoring"
        echo "  13 - All Tests (Production Readiness)"
        exit 1
        ;;
esac

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}=== All tests passed! ===${NC}"
else
    echo -e "${RED}=== Some tests failed ===${NC}"
    exit 1
fi
