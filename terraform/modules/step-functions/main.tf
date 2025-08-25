# Step Functions Module
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

variable "step_function_role_arn" {
  description = "Step Function role ARN"
  type        = string
}

variable "glue_job_names" {
  description = "List of Glue job names to be orchestrated"
  type        = list(string)
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB control table"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# Step Functions State Machine Definition (Amazon States Language)
locals {
  state_machine_definition = jsonencode({
    Comment = "Medallion Data Pipeline Orchestration",
    StartAt = "GetProcessingConfig",
    States = {
      GetProcessingConfig = {
        Type = "Task",
        Resource = "arn:aws:states:::dynamodb:getItem",
        Parameters = {
          TableName = var.dynamodb_table_name,
          Key = {
            table_name = {
              "S.$" = "$.key"
            }
          }
        },
        ResultPath = "$.ProcessingConfig",
        Next = "DetermineProcessingStrategy"
      },
      DetermineProcessingStrategy = {
        Type = "Choice",
        Choices = [
          {
            Variable = "$.payload_size_mb",
            NumericLessThan = 400,
            Next = "ProcessWithLambda"
          },
          {
            Variable = "$.payload_size_mb",
            NumericLessThan = 10000, # Assuming 10GB as intermediate threshold
            Next = "ProcessWithEKS"
          }
        ],
        Default = "ProcessWithGlue"
      },
      ProcessWithLambda = {
        Type = "Task",
        Resource = "arn:aws:states:::lambda:invoke",
        Parameters = {
          FunctionName = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.naming_prefix}-dynamic-processor",
          Payload = {
            table_name = "$.key",
            payload_size_mb = "$.payload_size_mb",
            target_layer = "Bronze" # First processing step
          }
        },
        ResultPath = "$.LambdaResult",
        Next = "RunBronzeDQ"
      },
      ProcessWithEKS = {
        Type = "Task",
        Resource = "arn:aws:states:::aws-sdk:eks:startJob", # Conceptual, requires EKS integration
        Parameters = {
          clusterName = "${var.naming_prefix}-eks-cluster",
          jobName = "${var.naming_prefix}-spark-job",
          # ... other EKS job parameters
        },
        ResultPath = "$.EKSResult",
        Next = "RunBronzeDQ"
      },
      ProcessWithGlue = {
        Type = "Task",
        Resource = "arn:aws:states:::glue:startJobRun.sync",
        Parameters = {
          JobName = var.glue_job_names[0], # Assuming bronze_to_silver job
          Arguments = {
            "--source_path.$" = "$.key",
            "--target_path.$" = "$.ProcessingConfig.Item.bronze_path.S",
            "--database_name.$" = "$.ProcessingConfig.Item.bronze_database.S",
            "--table_name.$" = "$.ProcessingConfig.Item.table_name.S"
          }
        },
        ResultPath = "$.GlueResult",
        Next = "RunBronzeDQ"
      },
      RunBronzeDQ = {
        Type = "Task",
        Resource = "arn:aws:states:::glue:startDataQualityRuleRecommendationRun.sync", # Conceptual
        Parameters = {
          DataSource = {
            GlueTable = {
              DatabaseName = "${var.naming_prefix}_bronze",
              TableName = "$.key"
            }
          },
          Ruleset = "${var.naming_prefix}-bronze-dq"
        },
        ResultPath = "$.BronzeDQResult",
        Next = "ProcessToSilver"
      },
      ProcessToSilver = {
        Type = "Task",
        Resource = "arn:aws:states:::glue:startJobRun.sync",
        Parameters = {
          JobName = var.glue_job_names[0], # Assuming bronze_to_silver job
          Arguments = {
            "--source_path.$" = "$.ProcessingConfig.Item.bronze_path.S",
            "--target_path.$" = "$.ProcessingConfig.Item.silver_path.S",
            "--database_name.$" = "${var.naming_prefix}_silver",
            "--table_name.$" = "$.ProcessingConfig.Item.table_name.S"
          }
        },
        ResultPath = "$.SilverProcessingResult",
        Next = "RunSilverDQ"
      },
      RunSilverDQ = {
        Type = "Task",
        Resource = "arn:aws:states:::glue:startDataQualityRuleRecommendationRun.sync", # Conceptual
        Parameters = {
          DataSource = {
            GlueTable = {
              DatabaseName = "${var.naming_prefix}_silver",
              TableName = "$.key"
            }
          },
          Ruleset = "${var.naming_prefix}-silver-dq"
        },
        ResultPath = "$.SilverDQResult",
        Next = "ProcessToGold"
      },
      ProcessToGold = {
        Type = "Task",
        Resource = "arn:aws:states:::glue:startJobRun.sync",
        Parameters = {
          JobName = var.glue_job_names[1], # Assuming silver_to_gold job
          Arguments = {
            "--source_path.$" = "$.ProcessingConfig.Item.silver_path.S",
            "--target_fact_path.$" = "$.ProcessingConfig.Item.gold_path.S",
            "--silver_database_name.$" = "${var.naming_prefix}_silver",
            "--gold_database_name.$" = "${var.naming_prefix}_gold",
            "--table_name.$" = "$.ProcessingConfig.Item.table_name.S"
          }
        },
        ResultPath = "$.GoldProcessingResult",
        Next = "RunGoldDQ"
      },
      RunGoldDQ = {
        Type = "Task",
        Resource = "arn:aws:states:::glue:startDataQualityRuleRecommendationRun.sync", # Conceptual
        Parameters = {
          DataSource = {
            GlueTable = {
              DatabaseName = "${var.naming_prefix}_gold",
              TableName = "$.key"
            }
          },
          Ruleset = "${var.naming_prefix}-gold-dq"
        },
        ResultPath = "$.GoldDQResult",
        End = true
      }
    }
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "medallion_workflow" {
  name     = "${var.naming_prefix}-medallion-workflow"
  role_arn = var.step_function_role_arn
  definition = local.state_machine_definition

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-medallion-workflow"
  })
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Outputs
output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.medallion_workflow.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.medallion_workflow.name
}

