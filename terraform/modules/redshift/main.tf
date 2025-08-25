# Redshift Module for Redshift Serverless
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "naming_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "gold_bucket_name" {
  description = "Gold bucket name"
  type        = string
}

variable "redshift_role_arn" {
  description = "Redshift role ARN for S3 and Glue Catalog access"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# Redshift Serverless Namespace
resource "aws_redshiftserverless_namespace" "main" {
  namespace_name = "${var.naming_prefix}-namespace"
  admin_username = "admin"
  admin_user_password = "${var.project_name}#${var.environment}#${random_string.password.result}"
  
  iam_roles = [
    var.redshift_role_arn
  ]

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-namespace"
  })
}

# Redshift Serverless Workgroup
resource "aws_redshiftserverless_workgroup" "main" {
  workgroup_name = "${var.naming_prefix}-workgroup"
  namespace_name = aws_redshiftserverless_namespace.main.namespace_name
  
  base_capacity = 8 # Example capacity, adjust as needed

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-workgroup"
  })
}

# Random string for admin password
resource "random_string" "password" {
  length  = 16
  special = true
  override_special = "_!%^"
}

# Outputs
output "namespace_name" {
  description = "Name of the Redshift Serverless namespace"
  value       = aws_redshiftserverless_namespace.main.namespace_name
}

output "workgroup_name" {
  description = "Name of the Redshift Serverless workgroup"
  value       = aws_redshiftserverless_workgroup.main.workgroup_name
}

output "workgroup_endpoint" {
  description = "Endpoint of the Redshift Serverless workgroup"
  value       = aws_redshiftserverless_workgroup.main.endpoint[0].address
}

