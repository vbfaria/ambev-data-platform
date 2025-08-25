terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Variables
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ambev-data-platform"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "DataEngineering"
    CostCenter  = "Analytics"
  }
  
  # Naming convention: project-resource-environment-account
  naming_prefix = "${var.project_name}-${var.environment}"
  
  # S3 bucket names (must be globally unique)
  landing_bucket_name = "${local.naming_prefix}-landing-${local.account_id}"
  bronze_bucket_name  = "${local.naming_prefix}-bronze-${local.account_id}"
  silver_bucket_name  = "${local.naming_prefix}-silver-${local.account_id}"
  gold_bucket_name    = "${local.naming_prefix}-gold-${local.account_id}"
  scripts_bucket_name = "${local.naming_prefix}-scripts-${local.account_id}"
}

# S3 Buckets for Medallion Architecture
module "s3_buckets" {
  source = "./modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  
  landing_bucket_name = local.landing_bucket_name
  bronze_bucket_name  = local.bronze_bucket_name
  silver_bucket_name  = local.silver_bucket_name
  gold_bucket_name    = local.gold_bucket_name
  scripts_bucket_name = local.scripts_bucket_name
  
  enable_deletion_protection = var.enable_deletion_protection
  
  tags = local.common_tags
}

# IAM Roles and Policies
module "iam" {
  source = "./modules/iam"
  
  project_name    = var.project_name
  environment     = var.environment
  naming_prefix   = local.naming_prefix
  
  landing_bucket_arn = module.s3_buckets.landing_bucket_arn
  bronze_bucket_arn  = module.s3_buckets.bronze_bucket_arn
  silver_bucket_arn  = module.s3_buckets.silver_bucket_arn
  gold_bucket_arn    = module.s3_buckets.gold_bucket_arn
  scripts_bucket_arn = module.s3_buckets.scripts_bucket_arn
  
  tags = local.common_tags
}

# DynamoDB Control Table
module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name  = var.project_name
  environment   = var.environment
  naming_prefix = local.naming_prefix
  
  enable_deletion_protection = var.enable_deletion_protection
  
  tags = local.common_tags
}

# Glue Catalog and Jobs
module "glue" {
  source = "./modules/glue"
  
  project_name  = var.project_name
  environment   = var.environment
  naming_prefix = local.naming_prefix
  
  landing_bucket_name = local.landing_bucket_name
  bronze_bucket_name  = local.bronze_bucket_name
  silver_bucket_name  = local.silver_bucket_name
  gold_bucket_name    = local.gold_bucket_name
  scripts_bucket_name = local.scripts_bucket_name
  
  glue_service_role_arn = module.iam.glue_service_role_arn
  
  tags = local.common_tags
}

# EventBridge Rules
module "eventbridge" {
  source = "./modules/eventbridge"
  
  project_name  = var.project_name
  environment   = var.environment
  naming_prefix = local.naming_prefix
  
  landing_bucket_name = local.landing_bucket_name
  step_function_arn   = module.step_functions.state_machine_arn
  eventbridge_role_arn = module.iam.eventbridge_role_arn
  
  tags = local.common_tags
}

# Step Functions State Machine
module "step_functions" {
  source = "./modules/step-functions"
  
  project_name  = var.project_name
  environment   = var.environment
  naming_prefix = local.naming_prefix
  
  step_function_role_arn = module.iam.step_function_role_arn
  glue_job_names = module.glue.glue_job_names
  dynamodb_table_name = module.dynamodb.control_table_name
  
  tags = local.common_tags
}

# Redshift Serverless
module "redshift" {
  source = "./modules/redshift"
  
  project_name  = var.project_name
  environment   = var.environment
  naming_prefix = local.naming_prefix
  
  gold_bucket_name = local.gold_bucket_name
  redshift_role_arn = module.iam.redshift_role_arn
  
  tags = local.common_tags
}

# Outputs
output "infrastructure_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    s3_buckets = {
      landing = module.s3_buckets.landing_bucket_name
      bronze  = module.s3_buckets.bronze_bucket_name
      silver  = module.s3_buckets.silver_bucket_name
      gold    = module.s3_buckets.gold_bucket_name
      scripts = module.s3_buckets.scripts_bucket_name
    }
    databases = {
      bronze_db = module.glue.bronze_database_name
      silver_db = module.glue.silver_database_name
      gold_db   = module.glue.gold_database_name
    }
    orchestration = {
      control_table    = module.dynamodb.control_table_name
      state_machine    = module.step_functions.state_machine_arn
      eventbridge_rule = module.eventbridge.eventbridge_rule_name
    }
    analytics = {
      redshift_workgroup = module.redshift.workgroup_name
      redshift_namespace = module.redshift.namespace_name
    }
  }
}

output "getting_started" {
  description = "Getting started information"
  value = {
    upload_data_to = "s3://${module.s3_buckets.landing_bucket_name}/sales/"
    query_endpoint = module.redshift.workgroup_endpoint
    crawler_name   = module.glue.bronze_crawler_name
  }
}

