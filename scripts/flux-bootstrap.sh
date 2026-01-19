#!/bin/bash
# =============================================================================
# Bead 5: Flux Bootstrap Script
# =============================================================================
# Usage: ./scripts/flux-bootstrap.sh
# Prerequisites:
#   - AWS CLI configured
#   - kubectl configured for EKS cluster
#   - GITHUB_TOKEN environment variable set
#   - flux CLI installed

set -euo pipefail

# Configuration
GITHUB_OWNER="${GITHUB_OWNER:-alexbenisch}"
GITHUB_REPO="${GITHUB_REPO:-aws-mercury-gitops}"
CLUSTER_PATH="${CLUSTER_PATH:-clusters/staging}"
BRANCH="${BRANCH:-main}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Flux Bootstrap for Mercury AWS ===${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v flux &> /dev/null; then
    echo -e "${RED}Error: flux CLI not found. Install with: curl -s https://fluxcd.io/install.sh | sudo bash${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo -e "${RED}Error: GITHUB_TOKEN environment variable not set${NC}"
    exit 1
fi

# Verify cluster connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

CLUSTER_NAME=$(kubectl config current-context)
echo -e "${GREEN}Connected to cluster: ${CLUSTER_NAME}${NC}"

# Check Flux prerequisites
echo -e "${YELLOW}Running Flux pre-flight checks...${NC}"
flux check --pre

# Bootstrap Flux
echo -e "${YELLOW}Bootstrapping Flux...${NC}"
flux bootstrap github \
    --owner="${GITHUB_OWNER}" \
    --repository="${GITHUB_REPO}" \
    --branch="${BRANCH}" \
    --path="${CLUSTER_PATH}" \
    --personal \
    --components-extra=image-reflector-controller,image-automation-controller

# Verify installation
echo -e "${YELLOW}Verifying Flux installation...${NC}"
flux check

echo -e "${GREEN}=== Flux Bootstrap Complete ===${NC}"
echo -e "Run 'flux get kustomizations' to check status"
