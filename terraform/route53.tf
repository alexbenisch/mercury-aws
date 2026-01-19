# =============================================================================
# Bead 11: DNS & External Access - Route53
# =============================================================================

# =============================================================================
# Bead 11.1: Route53 Records
# =============================================================================

# Note: This assumes you have an existing Route53 hosted zone
# If you need to create one, uncomment the resource below

# resource "aws_route53_zone" "main" {
#   name = var.domain_name
#
#   tags = {
#     Bead = "11"
#   }
# }

# Data source to get existing hosted zone
data "aws_route53_zone" "main" {
  count = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
}

# Get the NLB DNS name from Traefik service
# Note: This is populated after Traefik is deployed
# For initial setup, you may need to apply Terraform twice or manually update

# CNAME record for customer1 subdomain
resource "aws_route53_record" "customer1" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "customer1.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300

  # This will be the NLB DNS name - update after Traefik deployment
  records = [var.nlb_dns_name]

  lifecycle {
    ignore_changes = [records]
  }
}

# Wildcard CNAME for future subdomains (optional)
resource "aws_route53_record" "wildcard" {
  count   = var.route53_zone_id != "" && var.create_wildcard_record ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "*.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300

  records = [var.nlb_dns_name]

  lifecycle {
    ignore_changes = [records]
  }
}

# =============================================================================
# Additional Variables
# =============================================================================

variable "nlb_dns_name" {
  description = "NLB DNS name from Traefik service (update after deployment)"
  type        = string
  default     = "placeholder.elb.eu-west-1.amazonaws.com"
}

variable "create_wildcard_record" {
  description = "Whether to create a wildcard DNS record"
  type        = bool
  default     = false
}

# =============================================================================
# Route53 Outputs
# =============================================================================

output "customer1_fqdn" {
  description = "FQDN for customer1"
  value       = var.route53_zone_id != "" ? aws_route53_record.customer1[0].fqdn : "customer1.${var.domain_name}"
}
