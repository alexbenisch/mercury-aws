## AWS EKS Migration Roadmap - Mercury-GitOps

### Phase 1: AWS Foundation & Baseline Infrastructure (1-2 Wochen)

**1.1 AWS Account Setup**
```bash
# Terraform Backend für State Management
terraform {
  backend "s3" {
    bucket         = "mercury-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

**1.2 Core AWS Services (analog zu Azure)**
- **EKS Cluster** (statt AKS)
- **AWS Secrets Manager** (statt Azure Key Vault)
- **VPC mit Private/Public Subnets**
- **IAM Roles & Policies** (IRSA - IAM Roles for Service Accounts)
- **S3 Bucket** für CloudNativePG Backups (statt Azure Blob Storage)

**Terraform Module Struktur:**
```
aws-mercury-gitops/
├── main.tf                      # EKS Cluster, Flux, Secrets Manager
├── vpc.tf                       # VPC, Subnets, NAT Gateway
├── iam.tf                       # IRSA Policies für Secrets & S3
├── secrets-manager.tf           # Analog zu Key Vault
└── s3-backups.tf               # Backup Storage für CNPG
```

### Phase 2: EKS Cluster Deployment (Woche 1)

**2.1 EKS Terraform Config**
```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "mercury-eks-staging"
  cluster_version = "1.31"  # Latest stable

  # VPC Configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Managed Node Group (analog zu deinem D2s_v3)
  eks_managed_node_groups = {
    general = {
      desired_size = 2
      min_size     = 2
      max_size     = 4

      instance_types = ["t3.medium"]  # 2 vCPU, 4GB RAM
      capacity_type  = "ON_DEMAND"
    }
  }

  # Networking: Cilium statt VPC CNI
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    # aws-ebs-csi-driver für Persistent Volumes
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}
```

**2.2 Cilium Installation (statt AWS VPC CNI)**
```bash
# Nach EKS Cluster Creation
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.14.5 \
  --namespace kube-system \
  --set eni.enabled=true \
  --set ipam.mode=eni \
  --set egressMasqueradeInterfaces=eth0 \
  --set routingMode=native
```

### Phase 3: Secrets Management - AWS Secrets Manager Integration (Woche 1-2)

**3.1 Secrets Store CSI Driver für AWS**
```yaml
# infrastructure/controllers/base/secrets-store-csi.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: secrets-store-csi-driver
  namespace: flux-system
spec:
  interval: 1h
  url: https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: csi-secrets-store
  namespace: kube-system
spec:
  chart:
    spec:
      chart: secrets-store-csi-driver
      sourceRef:
        kind: HelmRepository
        name: secrets-store-csi-driver
  values:
    syncSecret:
      enabled: true
    enableSecretRotation: true
```

**3.2 AWS Secrets Manager Provider**
```bash
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

**3.3 IRSA Setup für Secrets Access**
```hcl
# iam.tf
module "secrets_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "mercury-secrets-manager-role"
  
  attach_secrets_manager_policy = true
  secrets_manager_arn           = aws_secretsmanager_secret.customer1_db.arn
  
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["customer1:default"]
    }
  }
}
```

**3.4 SecretProviderClass für Customer1**
```yaml
# apps/base/customer1/secrets.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: customer1-secrets
  namespace: customer1
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "customer1-db-credentials"
        objectType: "secretsmanager"
        jmesPath:
          - path: username
            objectAlias: customer1-db-user
          - path: password
            objectAlias: customer1-db-password
  secretObjects:
  - secretName: customer1-db-credentials
    type: Opaque
    data:
    - objectName: customer1-db-user
      key: username
    - objectName: customer1-db-password
      key: password
```

### Phase 4: Flux CD Setup (Woche 2)

**4.1 Flux Bootstrap auf EKS**
```bash
# Nach EKS Cluster ist ready
export GITHUB_TOKEN=<your-token>

flux bootstrap github \
  --owner=alexbenisch \
  --repository=aws-mercury-gitops \
  --branch=main \
  --path=clusters/staging \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller
```

**4.2 Kustomization Structure (identisch zu Azure)**
```yaml
# clusters/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - flux-system/
  - ../../infrastructure/controllers/staging
  - ../../infrastructure/configs/staging
  - ../../apps/staging
```

### Phase 5: Infrastructure Controllers (Woche 2)

**Identisch zu deinem Azure Setup:**
- Traefik (Load Balancer → AWS NLB)
- cert-manager mit Let's Encrypt
- CloudNativePG Operator

**AWS-spezifische Anpassungen:**

**5.1 Traefik mit AWS NLB**
```yaml
# infrastructure/controllers/staging/traefik-values.yaml
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
```

**5.2 cert-manager mit Route53 DNS Challenge**
```yaml
# infrastructure/configs/base/letsencrypt-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - dns01:
        route53:
          region: eu-west-1
          # IRSA wird automatisch verwendet
```

### Phase 6: CloudNativePG Backups zu S3 (Woche 3)

**6.1 S3 Bucket für Backups**
```hcl
# s3-backups.tf
resource "aws_s3_bucket" "cnpg_backups" {
  bucket = "mercury-cnpg-backups-staging"
}

resource "aws_s3_bucket_versioning" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"
    expiration {
      days = 30
    }
  }
}
```

**6.2 IRSA für S3 Access**
```hcl
module "cnpg_backup_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "mercury-cnpg-backup-role"
  
  attach_policy_statements = [
    {
      sid = "S3BackupAccess"
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.cnpg_backups.arn,
        "${aws_s3_bucket.cnpg_backups.arn}/*"
      ]
    }
  ]
  
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["customer1:postgres"]
    }
  }
}
```

**6.3 PostgreSQL Cluster mit S3 Backup**
```yaml
# apps/base/customer1/database.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: customer1-db
  namespace: customer1
spec:
  instances: 3
  
  serviceAccountTemplate:
    metadata:
      annotations:
        eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/mercury-cnpg-backup-role
  
  backup:
    barmanObjectStore:
      destinationPath: s3://mercury-cnpg-backups-staging/customer1
      s3Credentials:
        inheritFromIAMRole: true  # Verwendet IRSA statt explizite Keys
      wal:
        compression: gzip
        maxParallel: 2
    retentionPolicy: "30d"
  
  storage:
    size: 10Gi
    storageClass: gp3
```

### Phase 7: Application Migration (Woche 3)

**Apps bleiben größtenteils identisch**, nur kleine Anpassungen:

**7.1 Ingress mit AWS ALB Controller (Alternative zu Traefik)**
```yaml
# Optional: AWS Load Balancer Controller statt Traefik
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: customer1-ingress
  namespace: customer1
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
spec:
  ingressClassName: alb
  rules:
  - host: customer1.mercury.kubetest.uk
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: customer1-n8n
            port:
              number: 3008
```

### Phase 8: Monitoring & Observability (Woche 4)

**AWS-native Integration:**
```yaml
# infrastructure/controllers/base/aws-cloudwatch.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: aws-cloudwatch-metrics
  namespace: kube-system
spec:
  chart:
    spec:
      chart: aws-cloudwatch-metrics
      sourceRef:
        kind: HelmRepository
        name: eks-charts
  values:
    clusterName: mercury-eks-staging
```

### Vergleichstabelle: Azure ↔ AWS

| Komponente | Azure (aktuell) | AWS (Ziel) |
|------------|----------------|------------|
| Kubernetes | AKS | EKS |
| Secrets | Azure Key Vault | AWS Secrets Manager |
| Storage | Azure Blob | S3 |
| Identity | Managed Identity | IRSA (IAM Roles for Service Accounts) |
| Networking | Cilium ✅ | Cilium ✅ (gleich) |
| Load Balancer | Azure LB | AWS NLB/ALB |
| DNS | Azure DNS | Route53 |
| Monitoring | Azure Monitor | CloudWatch |

### Quick Start Commands für AWS

```bash
# 1. AWS CLI Setup
aws configure
aws eks update-kubeconfig --name mercury-eks-staging --region eu-west-1

# 2. Terraform Deploy
cd aws-mercury-gitops
terraform init
terraform plan
terraform apply

# 3. Flux Bootstrap
flux bootstrap github \
  --owner=alexbenisch \
  --repository=aws-mercury-gitops \
  --branch=main \
  --path=clusters/staging

# 4. Verify Deployment
kubectl get nodes
kubectl get pods -A
flux get kustomizations

# 5. Check Traefik LoadBalancer
kubectl get svc -n traefik

# 6. DNS Update
aws route53 change-resource-record-sets --hosted-zone-id Z123 \
  --change-batch file://dns-update.json
```

### Nächste Schritte

1. **Erstelle neues GitHub Repo:** `aws-mercury-gitops`
2. **Kopiere Struktur:** Von `mercury-gitops` als Basis
3. **Terraform AWS Modules:** Start mit `vpc.tf` und `eks.tf`
4. **Secrets Manager:** Setup der DB Credentials
5. **Flux Bootstrap:** Sobald EKS läuft

Brauchst du Hilfe bei einem bestimmten Teil? Z.B.:
- Komplettes Terraform-Setup für EKS?
- IRSA Configuration im Detail?
- CloudNativePG Backup-Test mit S3?
