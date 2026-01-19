# =============================================================================
# General Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
  default     = "staging"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "mercury"
}

# =============================================================================
# VPC Variables (Bead 1)
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# =============================================================================
# EKS Variables (Bead 2)
# =============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "mercury-eks-staging"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "Instance types for EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes in node group"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in node group"
  type        = number
  default     = 4
}

# =============================================================================
# Secrets Manager Variables (Bead 3)
# =============================================================================

variable "db_username" {
  description = "Database username for customer1"
  type        = string
  default     = "customer1_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Database password for customer1"
  type        = string
  sensitive   = true
}

# =============================================================================
# S3 Backup Variables (Bead 7)
# =============================================================================

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

# =============================================================================
# DNS Variables (Bead 11)
# =============================================================================

variable "domain_name" {
  description = "Base domain name for the application"
  type        = string
  default     = "mercury.kubetest.uk"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}
