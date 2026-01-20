#!/bin/bash
# =============================================================================
# Bead 1.0: Bootstrap Terraform Backend
# =============================================================================
# This script creates the S3 bucket and DynamoDB table required for Terraform
# state management BEFORE running terraform init.
#
# Solves the chicken-and-egg problem where terraform needs the backend to exist
# but the backend is defined in terraform.
#
# Usage: ./bootstrap-backend.sh
# =============================================================================

set -euo pipefail

# Configuration - must match versions.tf backend block
AWS_REGION="eu-west-1"
DYNAMODB_TABLE="terraform-locks"

# Get account ID for unique bucket name
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mercury-terraform-state-${ACCOUNT_ID}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Bead 1.0: Bootstrap Terraform Backend ===${NC}"
echo ""

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Using AWS Account: $ACCOUNT_ID${NC}"
echo -e "${GREEN}✓ Bucket name: $BUCKET_NAME${NC}"
echo ""

# Create S3 Bucket
echo "Creating S3 bucket: $BUCKET_NAME..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✓ Bucket already exists${NC}"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"
    echo -e "${GREEN}✓ Bucket created${NC}"
fi

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable encryption
echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "aws:kms"
            }
        }]
    }'
echo -e "${GREEN}✓ Encryption enabled${NC}"

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'
echo -e "${GREEN}✓ Public access blocked${NC}"

# Add bucket tags
echo "Adding tags..."
aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --tagging '{
        "TagSet": [
            {"Key": "Project", "Value": "mercury"},
            {"Key": "Environment", "Value": "staging"},
            {"Key": "ManagedBy", "Value": "bootstrap-script"},
            {"Key": "Bead", "Value": "1.0"}
        ]
    }'
echo -e "${GREEN}✓ Tags added${NC}"
echo ""

# Create DynamoDB Table
echo "Creating DynamoDB table: $DYNAMODB_TABLE..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${GREEN}✓ Table already exists${NC}"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Project,Value=mercury Key=Environment,Value=staging Key=ManagedBy,Value=bootstrap-script Key=Bead,Value=1.0

    echo "Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    echo -e "${GREEN}✓ Table created${NC}"
fi
echo ""

# Verification
echo -e "${YELLOW}=== Verification ===${NC}"
echo ""

echo "S3 Bucket:"
aws s3api head-bucket --bucket "$BUCKET_NAME" && echo -e "${GREEN}✓ Bucket exists${NC}"
aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query "Status" --output text | grep -q "Enabled" && echo -e "${GREEN}✓ Versioning enabled${NC}"

echo ""
echo "DynamoDB Table:"
TABLE_STATUS=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" --query "Table.TableStatus" --output text)
if [ "$TABLE_STATUS" == "ACTIVE" ]; then
    echo -e "${GREEN}✓ Table is ACTIVE${NC}"
else
    echo -e "${RED}✗ Table status: $TABLE_STATUS${NC}"
fi

echo ""
echo -e "${GREEN}=== Bootstrap Complete ===${NC}"
echo ""

# Update versions.tf with correct bucket name
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="$SCRIPT_DIR/versions.tf"

if grep -q 'bucket.*=.*"mercury-terraform-state"' "$VERSIONS_FILE"; then
    echo "Updating versions.tf with account-specific bucket name..."
    sed -i "s/bucket.*=.*\"mercury-terraform-state\"/bucket         = \"$BUCKET_NAME\"/" "$VERSIONS_FILE"
    echo -e "${GREEN}✓ Updated versions.tf${NC}"
fi

echo ""
echo "Next steps:"
echo "  1. cd terraform"
echo "  2. terraform init"
echo "  3. terraform plan -var=\"db_password=<your-password>\""
echo "  4. terraform apply -var=\"db_password=<your-password>\""
