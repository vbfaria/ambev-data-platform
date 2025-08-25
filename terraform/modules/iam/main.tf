# IAM Module for Data Platform - Comprehensive Security Setup
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

variable "landing_bucket_arn" {
  description = "Landing bucket ARN"
  type        = string
}

variable "bronze_bucket_arn" {
  description = "Bronze bucket ARN"
  type        = string
}

variable "silver_bucket_arn" {
  description = "Silver bucket ARN"
  type        = string
}

variable "gold_bucket_arn" {
  description = "Gold bucket ARN"
  type        = string
}

variable "scripts_bucket_arn" {
  description = "Scripts bucket ARN"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# =============================================================================
# AWS GLUE SERVICE ROLE AND POLICIES
# =============================================================================

# Glue Service Role
resource "aws_iam_role" "glue_service_role" {
  name = "${var.naming_prefix}-glue-service-role"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-glue-service-role"
    Service = "AWS Glue"
  })
}

# Attach AWS managed policy for Glue service
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom S3 policy for Glue
resource "aws_iam_policy" "glue_s3_policy" {
  name        = "${var.naming_prefix}-glue-s3-policy"
  description = "S3 access policy for Glue jobs and crawlers"
  path        = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketAcl"
        ]
        Resource = [
          var.landing_bucket_arn,
          var.bronze_bucket_arn,
          var.silver_bucket_arn,
          var.gold_bucket_arn,
          var.scripts_bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.landing_bucket_arn}/*",
          "${var.bronze_bucket_arn}/*",
          "${var.silver_bucket_arn}/*",
          "${var.gold_bucket_arn}/*",
          "${var.scripts_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_s3_policy_attachment" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = aws_iam_policy.glue_s3_policy.arn
}

# Lake Formation policy for Glue
resource "aws_iam_policy" "glue_lakeformation_policy" {
  name        = "${var.naming_prefix}-glue-lakeformation-policy"
  description = "Lake Formation access policy for Glue"
  path        = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess",
          "lakeformation:GrantPermissions",
          "lakeformation:RevokePermissions",
          "lakeformation:BatchGrantPermissions",
          "lakeformation:BatchRevokePermissions",
          "lakeformation:ListPermissions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateDatabase",
          "glue:UpdateDatabase",
          "glue:DeleteDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:BatchUpdatePartition"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:database/${var.project_name}_*_${var.environment}",
          "arn:aws:glue:${local.region}:${local.account_id}:table/${var.project_name}_*_${var.environment}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_lakeformation_policy_attachment" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = aws_iam_policy.glue_lakeformation_policy.arn
}

# CloudWatch Logs policy for Glue
resource "aws_iam_policy" "glue_cloudwatch_policy" {
  name        = "${var.naming_prefix}-glue-cloudwatch-policy"
  description = "CloudWatch Logs access policy for Glue"
  path        = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:AssociateKmsKey"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_cloudwatch_policy_attachment" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = aws_iam_policy.glue_cloudwatch_policy.arn
}

# =============================================================================
# STEP FUNCTIONS SERVICE ROLE AND POLICIES
# =============================================================================

# Step Functions Service Role
resource "aws_iam_role" "step_function_role" {
  name = "${var.naming_prefix}-step-function-role"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-step-function-role"
    Service = "AWS Step Functions"
  })
}

# Step Functions execution policy
resource "aws_iam_policy" "step_function_execution_policy" {
  name        = "${var.naming_prefix}-step-function-execution-policy"
  description = "Execution policy for Step Functions state machine"
  path        = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun",
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics",
          "glue:StopCrawler"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:job/${var.naming_prefix}-*",
          "arn:aws:glue:${local.region}:${local.account_id}:crawler/${var.naming_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.naming_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.naming_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "step_function_execution_policy_attachment" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.step_function_execution_policy.arn
}

# =============================================================================
# EVENTBRIDGE SERVICE ROLE AND POLICIES
# =============================================================================

# EventBridge Service Role
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.naming_prefix}-eventbridge-role"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-eventbridge-role"
    Service = "Amazon EventBridge"
  })
}

# EventBridge execution policy
resource "aws_iam_policy" "eventbridge_execution_policy" {
  name        = "${var.naming_prefix}-eventbridge-execution-policy"
  description = "Execution policy for EventBridge rules"
  path        = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          "arn:aws:states:${local.region}:${local.account_id}:stateMachine:${var.naming_prefix}-*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eventbridge_execution_policy_attachment" {
  role       = aws_iam_role.eventbridge_role.name
  policy_arn = aws_iam_policy.eventbridge_execution_policy.arn
}

# =============================================================================
# REDSHIFT SERVICE ROLE AND POLICIES
# =============================================================================

# Redshift Service Role
resource "aws_iam_role" "redshift_role" {
  name = "${var.naming_prefix}-redshift-role"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-redshift-role"
    Service = "Amazon Redshift"
  })
}

# Redshift S3 access policy
resource "aws_iam_policy" "redshift_s3_policy" {
  name        = "${var.naming_prefix}-redshift-s3-policy"
  description = "S3 access policy for Redshift Spectrum"
  path        = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = [
          var.gold_bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${var.gold_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "redshift_s3_policy_attachment" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = aws_iam_policy.redshift_s3_policy.arn
}

# Redshift Glue Catalog access policy
resource "aws_iam_policy" "redshift_glue_policy" {
  name        = "${var.naming_prefix}-redshift-glue-policy"
  description = "Glue Catalog access policy for Redshift Spectrum"
  path        = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:BatchUpdatePartition"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:database/${var.project_name}_gold_${var.environment}",
          "arn:aws:glue:${local.region}:${local.account_id}:table/${var.project_name}_gold_${var.environment}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "redshift_glue_policy_attachment" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = aws_iam_policy.redshift_glue_policy.arn
}

# =============================================================================
# LAMBDA EXECUTION ROLE (for dynamic processing)
# =============================================================================

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.naming_prefix}-lambda-execution-role"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-lambda-execution-role"
    Service = "AWS Lambda"
  })
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda S3 and DynamoDB access policy
resource "aws_iam_policy" "lambda_data_access_policy" {
  name        = "${var.naming_prefix}-lambda-data-access-policy"
  description = "Data access policy for Lambda functions"
  path        = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bronze_bucket_arn,
          "${var.bronze_bucket_arn}/*",
          var.silver_bucket_arn,
          "${var.silver_bucket_arn}/*",
          var.scripts_bucket_arn,
          "${var.scripts_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.naming_prefix}-*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_data_access_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_data_access_policy.arn
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "glue_service_role_arn" {
  description = "Glue service role ARN"
  value       = aws_iam_role.glue_service_role.arn
}

output "glue_service_role_name" {
  description = "Glue service role name"
  value       = aws_iam_role.glue_service_role.name
}

output "step_function_role_arn" {
  description = "Step Function role ARN"
  value       = aws_iam_role.step_function_role.arn
}

output "step_function_role_name" {
  description = "Step Function role name"
  value       = aws_iam_role.step_function_role.name
}

output "eventbridge_role_arn" {
  description = "EventBridge role ARN"
  value       = aws_iam_role.eventbridge_role.arn
}

output "eventbridge_role_name" {
  description = "EventBridge role name"
  value       = aws_iam_role.eventbridge_role.name
}

output "redshift_role_arn" {
  description = "Redshift role ARN"
  value       = aws_iam_role.redshift_role.arn
}

output "redshift_role_name" {
  description = "Redshift role name"
  value       = aws_iam_role.redshift_role.name
}

output "lambda_execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_execution_role_name" {
  description = "Lambda execution role name"
  value       = aws_iam_role.lambda_execution_role.name
}

