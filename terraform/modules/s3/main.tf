# S3 Module for Medallion Architecture
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "landing_bucket_name" {
  description = "Landing bucket name"
  type        = string
}

variable "bronze_bucket_name" {
  description = "Bronze bucket name"
  type        = string
}

variable "silver_bucket_name" {
  description = "Silver bucket name"
  type        = string
}

variable "gold_bucket_name" {
  description = "Gold bucket name"
  type        = string
}

variable "scripts_bucket_name" {
  description = "Scripts bucket name"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# Landing Zone S3 Bucket (Archive)
resource "aws_s3_bucket" "landing" {
  bucket = var.landing_bucket_name
  
  force_destroy = var.enable_deletion_protection ? false : true

  tags = merge(var.tags, {
    Name = "${var.project_name}-landing-${var.environment}"
    Layer = "Landing"
  })
}

resource "aws_s3_bucket_versioning" "landing" {
  bucket = aws_s3_bucket.landing.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_notification" "landing" {
  bucket = aws_s3_bucket.landing.id

  eventbridge = true
}

# Bronze Layer S3 Bucket
resource "aws_s3_bucket" "bronze" {
  bucket = var.bronze_bucket_name
  
  force_destroy = var.enable_deletion_protection ? false : true

  tags = merge(var.tags, {
    Name = "${var.project_name}-bronze-${var.environment}"
    Layer = "Bronze"
  })
}

resource "aws_s3_bucket_versioning" "bronze" {
  bucket = aws_s3_bucket.bronze.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bronze" {
  bucket = aws_s3_bucket.bronze.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Silver Layer S3 Bucket
resource "aws_s3_bucket" "silver" {
  bucket = var.silver_bucket_name
  
  force_destroy = var.enable_deletion_protection ? false : true

  tags = merge(var.tags, {
    Name = "${var.project_name}-silver-${var.environment}"
    Layer = "Silver"
  })
}

resource "aws_s3_bucket_versioning" "silver" {
  bucket = aws_s3_bucket.silver.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "silver" {
  bucket = aws_s3_bucket.silver.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Gold Layer S3 Bucket
resource "aws_s3_bucket" "gold" {
  bucket = var.gold_bucket_name
  
  force_destroy = var.enable_deletion_protection ? false : true

  tags = merge(var.tags, {
    Name = "${var.project_name}-gold-${var.environment}"
    Layer = "Gold"
  })
}

resource "aws_s3_bucket_versioning" "gold" {
  bucket = aws_s3_bucket.gold.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gold" {
  bucket = aws_s3_bucket.gold.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Scripts S3 Bucket
resource "aws_s3_bucket" "scripts" {
  bucket = var.scripts_bucket_name
  
  force_destroy = var.enable_deletion_protection ? false : true

  tags = merge(var.tags, {
    Name = "${var.project_name}-scripts-${var.environment}"
    Purpose = "Scripts"
  })
}

resource "aws_s3_bucket_versioning" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Outputs
output "landing_bucket_name" {
  description = "Landing bucket name"
  value       = aws_s3_bucket.landing.bucket
}

output "landing_bucket_arn" {
  description = "Landing bucket ARN"
  value       = aws_s3_bucket.landing.arn
}

output "bronze_bucket_name" {
  description = "Bronze bucket name"
  value       = aws_s3_bucket.bronze.bucket
}

output "bronze_bucket_arn" {
  description = "Bronze bucket ARN"
  value       = aws_s3_bucket.bronze.arn
}

output "silver_bucket_name" {
  description = "Silver bucket name"
  value       = aws_s3_bucket.silver.bucket
}

output "silver_bucket_arn" {
  description = "Silver bucket ARN"
  value       = aws_s3_bucket.silver.arn
}

output "gold_bucket_name" {
  description = "Gold bucket name"
  value       = aws_s3_bucket.gold.bucket
}

output "gold_bucket_arn" {
  description = "Gold bucket ARN"
  value       = aws_s3_bucket.gold.arn
}

output "scripts_bucket_name" {
  description = "Scripts bucket name"
  value       = aws_s3_bucket.scripts.bucket
}

output "scripts_bucket_arn" {
  description = "Scripts bucket ARN"
  value       = aws_s3_bucket.scripts.arn
}

