# Mercury AWS Migration - Deployment Plan

## Overview
Migration from Azure (AKS) to AWS (EKS) broken into testable beads.

---

## Bead 1: AWS Foundation Setup

### 1.1 Terraform Backend
- [ ] Create S3 bucket `mercury-terraform-state`
- [ ] Create DynamoDB table `terraform-locks`
- [ ] Configure backend in `main.tf`

**Test:** `terraform init` succeeds without errors

### 1.2 VPC Infrastructure
- [ ] Create VPC with CIDR block
- [ ] Create 3 public subnets (multi-AZ)
- [ ] Create 3 private subnets (multi-AZ)
- [ ] Create Internet Gateway
- [ ] Create NAT Gateway
- [ ] Configure route tables

**Test:**
```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=mercury-*"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
```

---

## Bead 2: EKS Cluster Deployment

### 2.1 EKS Cluster Core
- [ ] Deploy EKS cluster with Terraform module
- [ ] Configure cluster version 1.31
- [ ] Enable OIDC provider
- [ ] Install CoreDNS addon
- [ ] Install kube-proxy addon
- [ ] Install aws-ebs-csi-driver addon

**Test:**
```bash
aws eks describe-cluster --name mercury-eks-staging
kubectl get nodes
kubectl cluster-info
```

### 2.2 Managed Node Group
- [ ] Create node group with t3.medium instances
- [ ] Configure min/max/desired capacity (2/4/2)
- [ ] Verify nodes join cluster

**Test:**
```bash
kubectl get nodes -o wide
kubectl describe nodes | grep -A5 "Allocatable"
```

### 2.3 Cilium CNI
- [ ] Install Cilium Helm chart
- [ ] Configure ENI mode
- [ ] Verify pod networking

**Test:**
```bash
cilium status
kubectl run test-pod --image=nginx --restart=Never
kubectl exec test-pod -- curl -s ifconfig.me
kubectl delete pod test-pod
```

---

## Bead 3: IAM & Security Foundation

### 3.1 IRSA Configuration
- [ ] Enable IRSA on EKS cluster
- [ ] Create OIDC identity provider
- [ ] Create base IAM policies

**Test:**
```bash
aws eks describe-cluster --name mercury-eks-staging --query "cluster.identity.oidc.issuer"
aws iam list-open-id-connect-providers
```

### 3.2 Secrets Manager Setup
- [ ] Create Secrets Manager secret for customer1-db
- [ ] Add username/password JSON
- [ ] Create IAM role for secrets access
- [ ] Bind role to service account

**Test:**
```bash
aws secretsmanager get-secret-value --secret-id customer1-db-credentials
```

---

## Bead 4: Secrets Store CSI Driver

### 4.1 CSI Driver Installation
- [ ] Create HelmRepository for secrets-store-csi-driver
- [ ] Deploy HelmRelease for csi-secrets-store
- [ ] Enable syncSecret and rotation

**Test:**
```bash
kubectl get pods -n kube-system | grep secrets-store
kubectl get csidriver
```

### 4.2 AWS Provider
- [ ] Install AWS Secrets Manager provider
- [ ] Verify provider pods running

**Test:**
```bash
kubectl get pods -n kube-system | grep csi-secrets-store-provider-aws
```

### 4.3 SecretProviderClass
- [ ] Create SecretProviderClass for customer1
- [ ] Configure JMES path mappings
- [ ] Configure secretObjects for K8s secret sync

**Test:**
```bash
kubectl get secretproviderclass -n customer1
kubectl describe secretproviderclass customer1-secrets -n customer1
```

---

## Bead 5: Flux CD Bootstrap

### 5.1 Flux Installation
- [ ] Bootstrap Flux with GitHub repository
- [ ] Configure path to clusters/staging
- [ ] Install image-reflector-controller
- [ ] Install image-automation-controller

**Test:**
```bash
flux check
flux get sources git
flux get kustomizations
```

### 5.2 Repository Structure
- [ ] Create clusters/staging/kustomization.yaml
- [ ] Link infrastructure/controllers
- [ ] Link infrastructure/configs
- [ ] Link apps directory

**Test:**
```bash
flux reconcile kustomization flux-system --with-source
kubectl get kustomization -n flux-system
```

---

## Bead 6: Infrastructure Controllers

### 6.1 Traefik Ingress Controller
- [ ] Create HelmRepository for Traefik
- [ ] Deploy HelmRelease with AWS NLB annotations
- [ ] Configure cross-zone load balancing

**Test:**
```bash
kubectl get svc -n traefik
kubectl get pods -n traefik
curl -I http://<NLB-DNS>
```

### 6.2 cert-manager
- [ ] Deploy cert-manager Helm chart
- [ ] Create IAM role for Route53 access
- [ ] Create ClusterIssuer for Let's Encrypt staging
- [ ] Create ClusterIssuer for Let's Encrypt production

**Test:**
```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-staging
```

### 6.3 CloudNativePG Operator
- [ ] Create HelmRepository for CNPG
- [ ] Deploy CNPG operator
- [ ] Verify CRDs installed

**Test:**
```bash
kubectl get pods -n cnpg-system
kubectl get crd | grep cnpg
```

---

## Bead 7: S3 Backup Infrastructure

### 7.1 S3 Bucket
- [ ] Create S3 bucket `mercury-cnpg-backups-staging`
- [ ] Enable versioning
- [ ] Configure lifecycle policy (30 day expiration)
- [ ] Block public access

**Test:**
```bash
aws s3api head-bucket --bucket mercury-cnpg-backups-staging
aws s3api get-bucket-versioning --bucket mercury-cnpg-backups-staging
```

### 7.2 IRSA for CNPG
- [ ] Create IAM policy for S3 access
- [ ] Create IAM role with trust policy
- [ ] Bind to postgres service account

**Test:**
```bash
aws iam get-role --role-name mercury-cnpg-backup-role
```

---

## Bead 8: Customer1 Namespace Deployment

### 8.1 Namespace & RBAC
- [ ] Create customer1 namespace
- [ ] Create service account with IRSA annotations
- [ ] Configure network policies (if needed)

**Test:**
```bash
kubectl get ns customer1
kubectl get sa -n customer1
kubectl describe sa default -n customer1
```

### 8.2 Secrets Integration
- [ ] Deploy SecretProviderClass
- [ ] Create test pod mounting the secret
- [ ] Verify K8s secret synced

**Test:**
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secrets-test
  namespace: customer1
spec:
  serviceAccountName: default
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: secrets
      mountPath: /mnt/secrets
      readOnly: true
  volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: customer1-secrets
EOF
kubectl exec -n customer1 secrets-test -- cat /mnt/secrets/customer1-db-user
kubectl get secret customer1-db-credentials -n customer1
kubectl delete pod secrets-test -n customer1
```

---

## Bead 9: PostgreSQL Cluster

### 9.1 Database Deployment
- [ ] Create PostgreSQL Cluster manifest
- [ ] Configure 3 instances
- [ ] Set service account with IRSA
- [ ] Configure gp3 storage class

**Test:**
```bash
kubectl get cluster -n customer1
kubectl get pods -n customer1 -l cnpg.io/cluster=customer1-db
kubectl cnpg status customer1-db -n customer1
```

### 9.2 Backup Configuration
- [ ] Configure barmanObjectStore for S3
- [ ] Set WAL compression
- [ ] Configure retention policy

**Test:**
```bash
# Trigger manual backup
kubectl cnpg backup customer1-db -n customer1
# Wait and verify
kubectl get backup -n customer1
aws s3 ls s3://mercury-cnpg-backups-staging/customer1/
```

### 9.3 Backup Restore Test
- [ ] Create test database and table
- [ ] Perform backup
- [ ] Restore to new cluster
- [ ] Verify data integrity

**Test:**
```bash
# Connect and create test data
kubectl cnpg psql customer1-db -n customer1 -- -c "CREATE TABLE test(id int); INSERT INTO test VALUES(1);"
# Backup
kubectl cnpg backup customer1-db -n customer1
# Restore to new cluster and verify
```

---

## Bead 10: Application Deployment

### 10.1 n8n Application
- [ ] Create Deployment manifest
- [ ] Configure environment variables from secrets
- [ ] Create Service
- [ ] Create IngressRoute (Traefik)

**Test:**
```bash
kubectl get deploy -n customer1
kubectl get pods -n customer1 -l app=n8n
kubectl logs -n customer1 -l app=n8n --tail=50
```

### 10.2 TLS Certificate
- [ ] Create Certificate resource
- [ ] Reference ClusterIssuer
- [ ] Verify certificate issued

**Test:**
```bash
kubectl get certificate -n customer1
kubectl describe certificate customer1-tls -n customer1
kubectl get secret customer1-tls -n customer1
```

### 10.3 Ingress/IngressRoute
- [ ] Create IngressRoute for n8n
- [ ] Configure TLS termination
- [ ] Set host rules

**Test:**
```bash
kubectl get ingressroute -n customer1
curl -I https://customer1.mercury.kubetest.uk
```

---

## Bead 11: DNS & External Access

### 11.1 Route53 Configuration
- [ ] Get NLB DNS name
- [ ] Create/update A record or CNAME
- [ ] Configure TTL

**Test:**
```bash
dig customer1.mercury.kubetest.uk
nslookup customer1.mercury.kubetest.uk
```

### 11.2 End-to-End Connectivity
- [ ] Verify HTTPS access
- [ ] Test certificate validity
- [ ] Test application functionality

**Test:**
```bash
curl -v https://customer1.mercury.kubetest.uk
openssl s_client -connect customer1.mercury.kubetest.uk:443 -servername customer1.mercury.kubetest.uk </dev/null 2>/dev/null | openssl x509 -noout -dates
```

---

## Bead 12: Monitoring & Observability

### 12.1 CloudWatch Integration
- [ ] Deploy aws-cloudwatch-metrics Helm chart
- [ ] Configure cluster name
- [ ] Verify metrics collection

**Test:**
```bash
kubectl get pods -n amazon-cloudwatch
aws cloudwatch list-metrics --namespace ContainerInsights --dimensions Name=ClusterName,Value=mercury-eks-staging
```

### 12.2 Logging
- [ ] Configure Fluent Bit or CloudWatch agent
- [ ] Verify logs appearing in CloudWatch

**Test:**
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/eks/mercury-eks-staging
```

---

## Bead 13: Production Readiness

### 13.1 Security Hardening
- [ ] Review and tighten IAM policies
- [ ] Enable VPC Flow Logs
- [ ] Configure Security Groups
- [ ] Enable encryption at rest

### 13.2 High Availability
- [ ] Verify multi-AZ distribution
- [ ] Test node failure recovery
- [ ] Test pod disruption budgets

### 13.3 Disaster Recovery
- [ ] Document restore procedures
- [ ] Test full cluster restore
- [ ] Verify RTO/RPO targets

---

## Execution Order Summary

| Bead | Dependencies | Estimated Effort |
|------|--------------|------------------|
| 1 | None | Foundation |
| 2 | Bead 1 | Core cluster |
| 3 | Bead 2 | Security setup |
| 4 | Bead 3 | Secrets integration |
| 5 | Bead 2 | GitOps |
| 6 | Bead 5 | Controllers |
| 7 | Bead 3 | Backup storage |
| 8 | Bead 4, 6 | Namespace ready |
| 9 | Bead 7, 8 | Database |
| 10 | Bead 9 | Application |
| 11 | Bead 10 | External access |
| 12 | Bead 2 | Observability |
| 13 | All | Production |

---

## Rollback Procedures

Each bead can be rolled back independently:

- **Terraform resources:** `terraform destroy -target=<resource>`
- **Flux resources:** `flux delete kustomization <name>`
- **Helm releases:** `helm uninstall <release> -n <namespace>`
- **K8s resources:** `kubectl delete -f <manifest>`

## Notes

- Always test in staging before production
- Keep Terraform state backed up
- Document any deviations from plan
- Each bead should be fully tested before proceeding to the next
