# Glue Module for Catalog and Jobs
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

variable "glue_service_role_arn" {
  description = "Glue service role ARN"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# Glue Catalog Databases
resource "aws_glue_catalog_database" "bronze_db" {
  name = "${var.naming_prefix}_bronze"
  
  description = "Bronze layer database for raw data"
  
  tags = merge(var.tags, {
    Layer = "Bronze"
  })
}

resource "aws_glue_catalog_database" "silver_db" {
  name = "${var.naming_prefix}_silver"
  
  description = "Silver layer database for cleaned and conformed data"
  
  tags = merge(var.tags, {
    Layer = "Silver"
  })
}

resource "aws_glue_catalog_database" "gold_db" {
  name = "${var.naming_prefix}_gold"
  
  description = "Gold layer database for curated business-ready data"
  
  tags = merge(var.tags, {
    Layer = "Gold"
  })
}

# Glue Crawler for Bronze Layer (Schema Inference)
resource "aws_glue_crawler" "bronze_crawler" {
  database_name = aws_glue_catalog_database.bronze_db.name
  name          = "${var.naming_prefix}-bronze-crawler"
  role          = var.glue_service_role_arn

  s3_target {
    path = "s3://${var.bronze_bucket_name}/"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })

  tags = merge(var.tags, {
    Layer = "Bronze"
  })
}

# Silver Layer Tables with Correct Data Types
resource "aws_glue_catalog_table" "silver_sales" {
  name          = "sales"
  database_name = aws_glue_catalog_database.silver_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                   = "parquet"
    "compressionType"                  = "none"
    "typeOfData"                       = "file"
    "useGlueParquetWriter"            = "true"
    "projection.enabled"               = "false"
  }

  storage_descriptor {
    location      = "s3://${var.silver_bucket_name}/sales/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "my-stream"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "date"
      type = "date"
    }

    columns {
      name = "brand_nm"
      type = "string"
    }

    columns {
      name = "trade_group_desc"
      type = "string"
    }

    columns {
      name = "btlr_org_lvl_c_desc"
      type = "string"
    }

    columns {
      name = "volume"
      type = "double"
    }

    columns {
      name = "year"
      type = "int"
    }

    columns {
      name = "month"
      type = "int"
    }

    columns {
      name = "day"
      type = "int"
    }
  }

  partition_keys {
    name = "year"
    type = "int"
  }

  partition_keys {
    name = "month"
    type = "int"
  }
}

# Gold Layer Dimensional Tables
resource "aws_glue_catalog_table" "gold_fact_sales" {
  name          = "fact_sales"
  database_name = aws_glue_catalog_database.gold_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                   = "iceberg"
    "table_type"                      = "ICEBERG"
    "metadata_location"               = "s3://${var.gold_bucket_name}/fact_sales/metadata/"
  }

  storage_descriptor {
    location      = "s3://${var.gold_bucket_name}/fact_sales/"
    input_format  = "org.apache.iceberg.mr.hive.HiveIcebergInputFormat"
    output_format = "org.apache.iceberg.mr.hive.HiveIcebergOutputFormat"

    ser_de_info {
      name                  = "iceberg-serde"
      serialization_library = "org.apache.iceberg.mr.hive.HiveIcebergSerDe"
    }

    columns {
      name = "sales_id"
      type = "bigint"
    }

    columns {
      name = "date_key"
      type = "int"
    }

    columns {
      name = "brand_key"
      type = "int"
    }

    columns {
      name = "trade_group_key"
      type = "int"
    }

    columns {
      name = "region_key"
      type = "int"
    }

    columns {
      name = "volume"
      type = "double"
    }
  }
}

resource "aws_glue_catalog_table" "gold_dim_time" {
  name          = "dim_time"
  database_name = aws_glue_catalog_database.gold_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                   = "iceberg"
    "table_type"                      = "ICEBERG"
    "metadata_location"               = "s3://${var.gold_bucket_name}/dim_time/metadata/"
  }

  storage_descriptor {
    location      = "s3://${var.gold_bucket_name}/dim_time/"
    input_format  = "org.apache.iceberg.mr.hive.HiveIcebergInputFormat"
    output_format = "org.apache.iceberg.mr.hive.HiveIcebergOutputFormat"

    ser_de_info {
      name                  = "iceberg-serde"
      serialization_library = "org.apache.iceberg.mr.hive.HiveIcebergSerDe"
    }

    columns {
      name = "date_key"
      type = "int"
    }

    columns {
      name = "date"
      type = "date"
    }

    columns {
      name = "year"
      type = "int"
    }

    columns {
      name = "month"
      type = "int"
    }

    columns {
      name = "day"
      type = "int"
    }

    columns {
      name = "quarter"
      type = "int"
    }

    columns {
      name = "month_name"
      type = "string"
    }

    columns {
      name = "day_of_week"
      type = "int"
    }

    columns {
      name = "day_name"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "gold_dim_brand" {
  name          = "dim_brand"
  database_name = aws_glue_catalog_database.gold_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                   = "iceberg"
    "table_type"                      = "ICEBERG"
    "metadata_location"               = "s3://${var.gold_bucket_name}/dim_brand/metadata/"
  }

  storage_descriptor {
    location      = "s3://${var.gold_bucket_name}/dim_brand/"
    input_format  = "org.apache.iceberg.mr.hive.HiveIcebergInputFormat"
    output_format = "org.apache.iceberg.mr.hive.HiveIcebergOutputFormat"

    ser_de_info {
      name                  = "iceberg-serde"
      serialization_library = "org.apache.iceberg.mr.hive.HiveIcebergSerDe"
    }

    columns {
      name = "brand_key"
      type = "int"
    }

    columns {
      name = "brand_nm"
      type = "string"
    }

    columns {
      name = "brand_category"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "gold_dim_trade_group" {
  name          = "dim_trade_group"
  database_name = aws_glue_catalog_database.gold_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                   = "iceberg"
    "table_type"                      = "ICEBERG"
    "metadata_location"               = "s3://${var.gold_bucket_name}/dim_trade_group/metadata/"
  }

  storage_descriptor {
    location      = "s3://${var.gold_bucket_name}/dim_trade_group/"
    input_format  = "org.apache.iceberg.mr.hive.HiveIcebergInputFormat"
    output_format = "org.apache.iceberg.mr.hive.HiveIcebergOutputFormat"

    ser_de_info {
      name                  = "iceberg-serde"
      serialization_library = "org.apache.iceberg.mr.hive.HiveIcebergSerDe"
    }

    columns {
      name = "trade_group_key"
      type = "int"
    }

    columns {
      name = "trade_group_desc"
      type = "string"
    }

    columns {
      name = "trade_type"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "gold_dim_region" {
  name          = "dim_region"
  database_name = aws_glue_catalog_database.gold_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                   = "iceberg"
    "table_type"                      = "ICEBERG"
    "metadata_location"               = "s3://${var.gold_bucket_name}/dim_region/metadata/"
  }

  storage_descriptor {
    location      = "s3://${var.gold_bucket_name}/dim_region/"
    input_format  = "org.apache.iceberg.mr.hive.HiveIcebergInputFormat"
    output_format = "org.apache.iceberg.mr.hive.HiveIcebergOutputFormat"

    ser_de_info {
      name                  = "iceberg-serde"
      serialization_library = "org.apache.iceberg.mr.hive.HiveIcebergSerDe"
    }

    columns {
      name = "region_key"
      type = "int"
    }

    columns {
      name = "btlr_org_lvl_c_desc"
      type = "string"
    }

    columns {
      name = "region_type"
      type = "string"
    }
  }
}

# Glue Jobs for Data Processing
resource "aws_glue_job" "bronze_to_silver" {
  name         = "${var.naming_prefix}-bronze-to-silver"
  role_arn     = var.glue_service_role_arn
  glue_version = "4.0"

  command {
    script_location = "s3://${var.scripts_bucket_name}/glue/bronze_to_silver.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${var.bronze_bucket_name}/spark-logs/"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.bronze_bucket_name}/temp/"
    "--enable-glue-datacatalog"          = "true"
    "--datalake-formats"                 = "iceberg"
  }

  max_retries = 1
  timeout     = 60

  tags = merge(var.tags, {
    JobType = "Bronze to Silver"
  })
}

resource "aws_glue_job" "silver_to_gold" {
  name         = "${var.naming_prefix}-silver-to-gold"
  role_arn     = var.glue_service_role_arn
  glue_version = "4.0"

  command {
    script_location = "s3://${var.scripts_bucket_name}/glue/silver_to_gold.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${var.silver_bucket_name}/spark-logs/"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.silver_bucket_name}/temp/"
    "--enable-glue-datacatalog"          = "true"
    "--datalake-formats"                 = "iceberg"
  }

  max_retries = 1
  timeout     = 60

  tags = merge(var.tags, {
    JobType = "Silver to Gold"
  })
}

# Data Quality Rulesets
resource "aws_glue_data_quality_ruleset" "bronze_data_quality" {
  name        = "${var.naming_prefix}-bronze-dq"
  description = "Data quality rules for Bronze layer"
  ruleset     = "Rules = [ColumnCount > 0, IsComplete \"DATE\", IsComplete \"BRAND_NM\"]"

  target_table {
    database_name = aws_glue_catalog_database.bronze_db.name
    table_name    = "sales"
  }

  tags = merge(var.tags, {
    Layer = "Bronze"
  })
}

resource "aws_glue_data_quality_ruleset" "silver_data_quality" {
  name        = "${var.naming_prefix}-silver-dq"
  description = "Data quality rules for Silver layer"
  ruleset     = "Rules = [IsComplete \"DATE\", IsComplete \"BRAND_NM\", IsComplete \"TRADE_GROUP_DESC\", ColumnDataType \"VOLUME\" = \"double\"]"

  target_table {
    database_name = aws_glue_catalog_database.silver_db.name
    table_name    = "sales"
  }

  tags = merge(var.tags, {
    Layer = "Silver"
  })
}

resource "aws_glue_data_quality_ruleset" "gold_data_quality" {
  name        = "${var.naming_prefix}-gold-dq"
  description = "Data quality rules for Gold layer"
  ruleset     = "Rules = [IsComplete \"VOLUME\", ColumnDataType \"VOLUME\" = \"double\", IsComplete \"date_key\", IsComplete \"brand_key\"]"

  target_table {
    database_name = aws_glue_catalog_database.gold_db.name
    table_name    = "fact_sales"
  }

  tags = merge(var.tags, {
    Layer = "Gold"
  })
}

# Outputs
output "bronze_database_name" {
  description = "Bronze database name"
  value       = aws_glue_catalog_database.bronze_db.name
}

output "silver_database_name" {
  description = "Silver database name"
  value       = aws_glue_catalog_database.silver_db.name
}

output "gold_database_name" {
  description = "Gold database name"
  value       = aws_glue_catalog_database.gold_db.name
}

output "glue_job_names" {
  description = "List of Glue job names"
  value = [
    aws_glue_job.bronze_to_silver.name,
    aws_glue_job.silver_to_gold.name
  ]
}

output "bronze_crawler_name" {
  description = "Bronze crawler name"
  value       = aws_glue_crawler.bronze_crawler.name
}

