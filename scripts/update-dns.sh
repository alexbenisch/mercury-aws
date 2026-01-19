#!/bin/bash
# =============================================================================
# Bead 11: Update DNS Records Script
# =============================================================================
# Usage: ./scripts/update-dns.sh
# Prerequisites:
#   - AWS CLI configured
#   - kubectl configured for EKS cluster
#   - Traefik deployed and NLB provisioned

set -euo pipefail

# Configuration
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
DOMAIN_NAME="${DOMAIN_NAME:-mercury.kubetest.uk}"
SUBDOMAIN="${SUBDOMAIN:-customer1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Update DNS Records ===${NC}"

# Get NLB DNS name from Traefik service
echo -e "${YELLOW}Getting NLB DNS name from Traefik service...${NC}"
NLB_DNS=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$NLB_DNS" ]; then
    echo -e "${RED}Error: Could not get NLB DNS name. Is Traefik deployed?${NC}"
    exit 1
fi

echo -e "${GREEN}NLB DNS: ${NLB_DNS}${NC}"

# Check if hosted zone ID is set
if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${YELLOW}HOSTED_ZONE_ID not set. Attempting to find hosted zone for ${DOMAIN_NAME}...${NC}"
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${DOMAIN_NAME}" --query "HostedZones[0].Id" --output text | sed 's|/hostedzone/||')

    if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" == "None" ]; then
        echo -e "${RED}Error: Could not find hosted zone for ${DOMAIN_NAME}${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Hosted Zone ID: ${HOSTED_ZONE_ID}${NC}"

# Create change batch JSON
CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Update ${SUBDOMAIN}.${DOMAIN_NAME} to point to NLB",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${SUBDOMAIN}.${DOMAIN_NAME}",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${NLB_DNS}"
          }
        ]
      }
    }
  ]
}
EOF
)

# Apply the change
echo -e "${YELLOW}Updating Route53 record...${NC}"
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "$CHANGE_BATCH" \
    --query "ChangeInfo.Id" \
    --output text)

echo -e "${GREEN}Change submitted: ${CHANGE_ID}${NC}"

# Wait for propagation
echo -e "${YELLOW}Waiting for DNS propagation...${NC}"
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"

echo -e "${GREEN}=== DNS Update Complete ===${NC}"
echo -e "Record: ${SUBDOMAIN}.${DOMAIN_NAME} -> ${NLB_DNS}"
echo ""
echo -e "${YELLOW}Verify with:${NC}"
echo "  dig ${SUBDOMAIN}.${DOMAIN_NAME}"
echo "  nslookup ${SUBDOMAIN}.${DOMAIN_NAME}"
