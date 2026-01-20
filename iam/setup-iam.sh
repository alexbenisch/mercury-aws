#!/bin/bash
# Setup IAM group and policies for Mercury deployment
# Run this with an admin account that has the bootstrap policy attached

set -e

GROUP_NAME="MercuryDeployers"
USER_NAME="devpod_otto"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

POLICIES=(
  "MercuryDeploymentPolicy-Core:mercury-deployment-policy-core.json"
  "MercuryDeploymentPolicy-Network:mercury-deployment-policy-network.json"
  "MercuryDeploymentPolicy-IAM:mercury-deployment-policy-iam.json"
  "MercuryDeploymentPolicy-Ops:mercury-deployment-policy-ops.json"
)

echo "Setting up IAM for Mercury deployment..."
echo "Account ID: $ACCOUNT_ID"
echo ""

# Create policies
for entry in "${POLICIES[@]}"; do
  POLICY_NAME="${entry%%:*}"
  POLICY_FILE="${entry##*:}"
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

  echo "Creating policy: $POLICY_NAME"
  if aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://${SCRIPT_DIR}/${POLICY_FILE}" \
    --query 'Policy.Arn' \
    --output text 2>/dev/null; then
    echo "  Created: $POLICY_ARN"
  else
    echo "  Already exists: $POLICY_ARN"
  fi
done

echo ""

# Create the group
echo "Creating group: $GROUP_NAME"
if aws iam create-group --group-name "$GROUP_NAME" 2>/dev/null; then
  echo "  Created group"
else
  echo "  Group already exists"
fi

echo ""

# Attach policies to the group
echo "Attaching policies to group..."
for entry in "${POLICIES[@]}"; do
  POLICY_NAME="${entry%%:*}"
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

  if aws iam attach-group-policy \
    --group-name "$GROUP_NAME" \
    --policy-arn "$POLICY_ARN" 2>/dev/null; then
    echo "  Attached: $POLICY_NAME"
  else
    echo "  Already attached or failed: $POLICY_NAME"
  fi
done

echo ""

# Add user to group (if user exists)
if aws iam get-user --user-name "$USER_NAME" &>/dev/null; then
  echo "Adding user $USER_NAME to group $GROUP_NAME..."
  aws iam add-user-to-group --user-name "$USER_NAME" --group-name "$GROUP_NAME" 2>/dev/null || echo "  Already in group"
else
  echo "User $USER_NAME does not exist. Create with:"
  echo "  aws iam create-user --user-name $USER_NAME"
  echo "  aws iam add-user-to-group --user-name $USER_NAME --group-name $GROUP_NAME"
  echo "  aws iam create-access-key --user-name $USER_NAME"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Verify with:"
echo "  aws iam get-group --group-name $GROUP_NAME"
echo "  aws iam list-attached-group-policies --group-name $GROUP_NAME"
