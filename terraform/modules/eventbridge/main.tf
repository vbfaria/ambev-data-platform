# EventBridge Module
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

variable "landing_bucket_name" {
  description = "Landing bucket name"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the Step Functions state machine to trigger"
  type        = string
}

variable "eventbridge_role_arn" {
  description = "EventBridge role ARN for triggering Step Functions"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# EventBridge Rule to trigger on S3 object creation in Landing bucket
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${var.naming_prefix}-s3-object-created"
  description = "Triggers when a new object is created in the landing S3 bucket"

  event_pattern = jsonencode({
    "source": [
      "aws.s3"
    ],
    "detail-type": [
      "AWS API Call via CloudTrail"
    ],
    "detail": {
      "eventSource": [
        "s3.amazonaws.com"
      ],
      "eventName": [
        "PutObject",
        "CompleteMultipartUpload"
      ],
      "requestParameters": {
        "bucketName": [
          var.landing_bucket_name
        ]
      }
    }
  })

  tags = merge(var.tags, {
    Name = "${var.naming_prefix}-s3-object-created"
  })
}

# EventBridge Target: Step Functions State Machine
resource "aws_cloudwatch_event_target" "step_function_target" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  arn       = var.step_function_arn
  role_arn  = var.eventbridge_role_arn

  input_transformer {
    input_paths = {
      "bucket_name" = "$.detail.requestParameters.bucketName"
      "key"         = "$.detail.requestParameters.key"
      "event_time"  = "$.time"
    }
    input_template = <<EOF
{
  "bucket_name": "<bucket_name>",
  "key": "<key>",
  "event_time": "<event_time>"
}
EOF
  }
}

# Outputs
output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.s3_object_created.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.s3_object_created.arn
}

