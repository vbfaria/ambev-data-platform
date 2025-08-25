# DynamoDB Module for Control Table
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

# DynamoDB Control Table
resource "aws_dynamodb_table" "control_table" {
  name           = "${var.project_name}-control-table-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "table_name"

  attribute {
    name = "table_name"
    type = "S"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-control-table-${var.environment}"
  })
  
  deletion_protection_enabled = var.enable_deletion_protection
}

# Sample control table items
resource "aws_dynamodb_table_item" "sales_config" {
  table_name = aws_dynamodb_table.control_table.name
  hash_key   = aws_dynamodb_table.control_table.hash_key

  item = jsonencode({
    table_name = {
      S = "sales_data"
    }
    source_path = {
      S = "s3://${var.project_name}-landing-${var.environment}-${data.aws_caller_identity.current.account_id}/sales/"
    }
    bronze_path = {
      S = "s3://${var.project_name}-bronze-${var.environment}-${data.aws_caller_identity.current.account_id}/sales/"
    }
    silver_path = {
      S = "s3://${var.project_name}-silver-${var.environment}-${data.aws_caller_identity.current.account_id}/sales/"
    }
    gold_path = {
      S = "s3://${var.project_name}-gold-${var.environment}-${data.aws_caller_identity.current.account_id}/sales/"
    }
    scripts_path = {
      S = "s3://${var.project_name}-scripts-${var.environment}-${data.aws_caller_identity.current.account_id}/"
    }
    format = {
      S = "parquet"
    }
    schema_version = {
      S = "1.0"
    }
    partition_columns = {
      SS = ["year", "month"]
    }
    data_quality_rules = {
      M = {
        bronze = {
          SS = ["ColumnCount > 0", "IsComplete \"DATE\"", "IsComplete \"BRAND_NM\""]
        }
        silver = {
          SS = ["IsComplete \"DATE\"", "IsComplete \"BRAND_NM\"", "IsComplete \"TRADE_GROUP_DESC\"", "ColumnDataType \"VOLUME\" = \"double\""]
        }
        gold = {
          SS = ["IsComplete \"DATE\"", "IsComplete \"BRAND_NM\"", "IsComplete \"TRADE_GROUP_DESC\"", "IsComplete \"Btlr_Org_LVL_C_Desc\"", "ColumnDataType \"VOLUME\" = \"double\""]
        }
      }
    }
  })
}

# Data sources
data "aws_caller_identity" "current" {}

# Outputs
output "control_table_name" {
  description = "Control table name"
  value       = aws_dynamodb_table.control_table.name
}

output "control_table_arn" {
  description = "Control table ARN"
  value       = aws_dynamodb_table.control_table.arn
}

