# Resume Notes - Mercury AWS Deployment

## Current Status (2026-01-20)
Infrastructure destroyed. Ready to redeploy tomorrow.

## Completed Beads
- **Bead 1**: AWS Foundation (VPC, S3 backend, DynamoDB locks)
- **Bead 2**: EKS Cluster (v1.31, 2 nodes, VPC CNI, EBS CSI)

## To Resume Tomorrow

### 1. Recreate Infrastructure
```bash
cd /workspaces/mercury-aws/terraform
terraform init
terraform apply
```

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --name mercury-eks-staging --region eu-west-1 --kubeconfig /workspaces/mercury-aws/.kube/config
export KUBECONFIG=/workspaces/mercury-aws/.kube/config
```

### 3. Continue with Bead 3
Next bead: **Bead 3: IAM & Security Foundation**

## Known Issues & Fixes Applied

### IAM Policy: EKS Access Entry Permissions
**Problem**: terraform-aws-modules/eks v20+ uses EKS Access Entries. The initial IAM policy was missing permissions.

**Error seen**:
```
AccessDeniedException: User is not authorized to perform: eks:DescribeAccessEntry
```

**Fix applied**: Updated `MercuryDeploymentPolicy-Core` (v2) to include:
- `eks:DescribeAccessEntry`
- `eks:ListAccessEntries`
- `eks:ListAccessPolicies`
- `eks:ListAssociatedAccessPolicies`
- `eks:DisassociateAccessPolicy`

**Note**: These permissions are in the `EKSClusterManagement` statement WITHOUT tag conditions.

### IAM Policy: EC2 Network Interface Permissions (Destroy)
**Problem**: During `terraform destroy`, deleting security groups and subnets requires ENI permissions.

**Error seen**:
```
UnauthorizedOperation: ec2:DescribeNetworkInterfaces action not allowed
```

**Fix applied**: Updated `MercuryDeploymentPolicy-Network` (v5) to include:
- `ec2:DescribeNetworkInterfaces`
- `ec2:DeleteNetworkInterface`
- `ec2:DescribeSecurityGroupRules`
- `ec2:DescribeVpcAttribute`
- `ec2:DescribeNetworkAcls`

### kubeconfig Path
**Problem**: Default `~/.kube/config` may be read-only in devcontainer.

**Solution**: Use workspace path:
```bash
--kubeconfig /workspaces/mercury-aws/.kube/config
```

### terraform.tfvars
**Required**: Create from example before applying:
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Set db_password to a secure value
```

## IAM Policies in AWS
The deployment uses split policies (due to size limits):
- `MercuryDeploymentPolicy-Core` (v2) - S3, DynamoDB, EKS
- `MercuryDeploymentPolicy-Ops` - CloudWatch, Logs
- `MercuryDeploymentPolicy-IAM` - IAM roles, OIDC
- `MercuryDeploymentPolicy-Network` (v5) - EC2, VPC, ELB, ENIs

## Bead Tracking
Use `bd` command to track progress:
```bash
bd list --status closed    # See completed beads
bd list --status open      # See remaining beads
bd close <bead-id>         # Close completed beads
```

## Files Modified Today
- `deployment-plan.md` - Updated with completion status and lessons learned
- `iam/mercury-deployment-policy.json` - Added EKS access entry + EC2 ENI permissions
- `terraform/terraform.tfvars` - Created (gitignored, contains db_password)
- `RESUME-NOTES.md` - This file with all findings
- AWS IAM: `MercuryDeploymentPolicy-Core` updated to v2
- AWS IAM: `MercuryDeploymentPolicy-Network` updated to v5
