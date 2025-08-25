# Ambev Data Platform

## Project Overview

This repository contains the infrastructure as code (IaC) and data processing scripts for a scalable and robust data platform designed for Ambev. The architecture leverages AWS services to implement a Medallion Lakehouse pattern, enabling efficient data ingestion, transformation, and consumption with a strong focus on data quality and operational automation.

## Architecture

The data platform is built on a Medallion Architecture (Landing, Bronze, Silver, Gold layers) within AWS, orchestrated by Step Functions and EventBridge, and managed by a DynamoDB control table. Data quality is enforced at each layer using AWS Glue Data Quality. Consumption is facilitated via Iceberg tables exposed through Redshift Spectrum.

Key components include:
- **AWS S3**: For data lake storage across all layers.
- **AWS Glue**: For ETL jobs, schema inference (Bronze), and Data Catalog management.
- **AWS DynamoDB**: A control table to manage dynamic processing configurations.
- **AWS Step Functions**: Orchestrates the end-to-end data pipeline, triggered by events.
- **AWS EventBridge**: Triggers Step Functions upon new file arrivals in the Landing S3 bucket.
- **AWS Lambda/EKS/Glue**: Dynamic processing engines based on data payload size.
- **Amazon Redshift Serverless**: For analytical querying of Gold layer data via Redshift Spectrum.
- **AWS IAM**: Comprehensive roles and policies for secure access and operations.

## Prerequisites

Before deploying this solution, ensure you have the following installed and configured:

- **AWS CLI**: Configured with appropriate credentials and default region.
- **Terraform**: Version 1.0 or higher.
- **Python 3.x**: For running data processing scripts and business queries.
- **Docker & Kubernetes (Optional)**: If you plan to run Spark on EKS locally for testing.

## Deployment

Follow these steps to deploy the AWS infrastructure using Terraform:

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd ambev-data-platform
    ```

2.  **Initialize Terraform:**
    Navigate to the `terraform` directory and initialize Terraform providers:
    ```bash
    cd terraform
    terraform init
    ```

3.  **Review the plan:**
    Generate and review the execution plan. This will show you what resources Terraform will create, modify, or destroy.
    ```bash
    terraform plan
    ```

4.  **Apply the changes:**
    Apply the Terraform configuration to deploy the infrastructure. Confirm with `yes` when prompted.
    ```bash
    terraform apply
    ```

    Upon successful deployment, Terraform will output key infrastructure details, including S3 bucket names, DynamoDB table name, and Step Functions ARN.

## Data Processing

Data processing follows the Medallion Architecture pattern:

1.  **Landing Zone (S3)**: Upload raw data files to the designated Landing S3 bucket (output from Terraform). This bucket also serves as an archive for original files.

2.  **Event-Driven Trigger**: An EventBridge rule detects new files in the Landing S3 bucket and triggers the Step Functions state machine.

3.  **Step Functions Orchestration**: The state machine orchestrates the data flow:
    -   Reads processing configurations from the DynamoDB control table.
    -   Selects the appropriate Spark execution engine (Lambda, EKS, or Glue) based on payload size.
    -   Executes data quality checks using AWS Glue Data Quality at each layer (Bronze, Silver, Gold).
    -   Transforms data from Bronze to Silver, and then from Silver to Gold.

4.  **Bronze Layer**: Raw data is converted to Parquet format, and its schema is inferred and registered in AWS Glue Catalog by a Glue Crawler.

5.  **Silver Layer**: Data is cleaned (duplicates removed, nulls handled), conformed, and validated. Data types are enforced to ensure consistency. Inconsistencies are logged and can be reviewed.

6.  **Gold Layer**: Curated, aggregated data is stored in Apache Iceberg format, optimized for analytical queries.

## Business Queries

The `scripts/sql/business_queries.sql` file contains example SQL queries to answer key business questions using the Gold layer data (accessible via Redshift Spectrum).

To execute these queries, connect to your Redshift Serverless endpoint using your preferred SQL client or BI tool.

### Example Queries:

-   **Top 3 Trade Groups per Region in Sales Volume**
-   **Monthly Sales Volume per Brand**
-   **Lowest Brand in Sales Volume per Region**

## Repository Structure

```
ambev-data-platform/
├── terraform/                  # Terraform IaC for AWS infrastructure
│   ├── main.tf                 # Main Terraform configuration
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── modules/                # Reusable Terraform modules
│   │   ├── s3/                 # S3 bucket definitions
│   │   ├── iam/                # IAM roles and policies
│   │   ├── dynamodb/           # DynamoDB control table
│   │   ├── glue/               # Glue Catalog, jobs, and DQ rules
│   │   ├── eventbridge/        # EventBridge rules
│   │   ├── step-functions/     # Step Functions state machine
│   │   └── redshift/           # Redshift Serverless setup
│   └── environments/
│       └── dev/                # Environment-specific configurations
├── scripts/                    # Data processing and utility scripts
│   ├── glue/                   # AWS Glue job scripts (e.g., Bronze to Silver, Silver to Gold)
│   ├── sql/                    # SQL queries for business insights
│   └── lambda/                 # Lambda function code for dynamic processing
├── docs/                       # Additional documentation (e.g., architecture diagrams)
├── tests/                      # Unit and integration tests
└── README.md                   # Project documentation
```

## Contributing

Contributions are welcome! Please refer to the contribution guidelines (if available) for details on how to submit pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.


