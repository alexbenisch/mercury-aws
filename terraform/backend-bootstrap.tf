# =============================================================================
# Bead 1.1: Backend Bootstrap Resources
# =============================================================================
# Run this FIRST with: terraform init -backend=false && terraform apply -target=module.backend
# Then reconfigure backend: terraform init -migrate-state

module "backend" {
  source = "./modules/backend"

  bucket_name    = "mercury-terraform-state-${data.aws_caller_identity.current.account_id}"
  dynamodb_table = "terraform-locks"
  aws_region     = var.aws_region
}
