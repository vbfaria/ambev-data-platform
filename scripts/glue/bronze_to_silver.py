"""
AWS Glue Job: Bronze to Silver Data Processing
This script processes data from the Bronze layer to the Silver layer in the Medallion Architecture.
It performs data cleaning, validation, and standardization using AWS Glue exclusively.
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import DataFrame
from pyspark.sql.functions import *
from pyspark.sql.types import *
import boto3
import json
from datetime import datetime

# Initialize Glue context
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'bronze_bucket',
    'silver_bucket',
    'control_table',
    'table_name',
    'database_name',
    'input_path' 
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
control_table = dynamodb.Table(args['control_table'])

def get_table_config(table_name):
    """
    Retrieve table configuration from DynamoDB control table
    """
    try:
        response = control_table.get_item(
            Key={'table_name': table_name}
        )
        if 'Item' in response:
            return response['Item']
        else:
            raise Exception(f"Configuration not found for table: {table_name}")
    except Exception as e:
        print(f"Error retrieving table configuration: {str(e)}")
        raise

def apply_data_quality_checks(df, table_config):
    """
    Apply data quality checks based on table configuration
    """
    print("Applying data quality checks...")
    
    # Get quality rules from configuration
    quality_rules = table_config.get('quality_rules', {})
    
    # Remove duplicates
    if quality_rules.get('remove_duplicates', True):
        initial_count = df.count()
        df = df.dropDuplicates()
        final_count = df.count()
        print(f"Removed {initial_count - final_count} duplicate records")
    
    # Remove null values for critical columns
    critical_columns = quality_rules.get('critical_columns', [])
    for column in critical_columns:
        if column in df.columns:
            initial_count = df.count()
            df = df.filter(col(column).isNotNull())
            final_count = df.count()
            print(f"Removed {initial_count - final_count} records with null {column}")
    
    # Data type validation and conversion
    schema_mapping = table_config.get('schema_mapping', {})
    for column_name, target_type in schema_mapping.items():
        if column_name in df.columns:
            try:
                if target_type == 'integer':
                    df = df.withColumn(column_name, col(column_name).cast(IntegerType()))
                elif target_type == 'double':
                    df = df.withColumn(column_name, col(column_name).cast(DoubleType()))
                elif target_type == 'date':
                    df = df.withColumn(column_name, to_date(col(column_name)))
                elif target_type == 'timestamp':
                    df = df.withColumn(column_name, to_timestamp(col(column_name)))
                print(f"Converted {column_name} to {target_type}")
            except Exception as e:
                print(f"Warning: Could not convert {column_name} to {target_type}: {str(e)}")
    
    return df

def standardize_column_names(df):
    """
    Standardize column names to follow naming conventions
    """
    print("Standardizing column names...")
    
    for column in df.columns:
        new_column = column.lower().replace(' ', '_').replace('-', '_').replace('$', '').replace('.', '')
        new_column = ''.join(c if c.isalnum() or c == '_' else '' for c in new_column)
        
        if new_column != column:
            df = df.withColumnRenamed(column, new_column)
            print(f"Renamed column: {column} -> {new_column}")
    
    return df

def add_metadata_columns(df):
    """
    Add metadata columns for data lineage and processing tracking
    """
    print("Adding metadata columns...")
    
    current_timestamp = datetime.now()
    
    df = df.withColumn("processed_timestamp", lit(current_timestamp)) \
           .withColumn("processing_layer", lit("silver")) \
           .withColumn("job_name", lit(args['JOB_NAME'])) \
           .withColumn("data_quality_passed", lit(True))
    
    return df

def process_bronze_to_silver():
    """
    Main processing function for Bronze to Silver transformation
    """
    table_name = args['table_name']
    bronze_bucket = args['bronze_bucket']
    silver_bucket = args['silver_bucket']
    database_name = args['database_name']
    input_path = args['input_path'] 
    
    print(f"Starting Bronze to Silver processing for table: {table_name}")
    
    # Get table configuration
    table_config = get_table_config(table_name)
    print(f"Retrieved configuration for table: {table_name}")
    
    print(f"Reading data from: {input_path}")
    
    try:
        bronze_dynamic_frame = glueContext.create_dynamic_frame.from_options(
            format_options={
                "quoteChar": '"',
                "withHeader": True,
                "separator": "\t" if "sales" in table_name else "," 
            },
            connection_type="s3",
            format="iceberg",  # Alterado para iceberg
            connection_options={
                "paths": [input_path],
                "recurse": True
            },
            transformation_ctx="bronze_dynamic_frame"
        )
        
        df = bronze_dynamic_frame.toDF()
        print(f"Successfully read {df.count()} records from input")
        
        df = standardize_column_names(df)
        df = apply_data_quality_checks(df, table_config)
        df = add_metadata_columns(df)
        

        silver_dynamic_frame = DynamicFrame.fromDF(df, glueContext, "silver_dynamic_frame")
        

        silver_path = f"s3://{silver_bucket}/{table_name}/"
        print(f"Writing data to: {silver_path}")
        
        glueContext.write_dynamic_frame.from_options(
            frame=silver_dynamic_frame,
            connection_type="s3",
            connection_options={
                "path": silver_path,
                "partitionKeys": table_config.get('partition_keys', [])
            },
            format="parquet",
            format_options={
                "compression": "snappy"
            },
            transformation_ctx="silver_write"
        )
        
        print(f"Successfully wrote {df.count()} records to Silver layer")
        

        update_glue_catalog(table_name, silver_path, df.schema, database_name)
        
        update_processing_status(table_name, "silver", "completed", df.count())
        
    except Exception as e:
        print(f"Error processing Bronze to Silver: {str(e)}")
        update_processing_status(table_name, "silver", "failed", 0, str(e))
        raise

def update_glue_catalog(table_name, s3_path, schema, database_name):
    """
    Update or create table in Glue Catalog
    """
    print(f"Updating Glue Catalog for table: {table_name}")
    
    glue_client = boto3.client('glue')
    
    columns = []
    for field in schema.fields:
        columns.append({
            'Name': field.name,
            'Type': str(field.dataType).lower().replace('type', '')
        })
    
    table_input = {
        'Name': f"{table_name}_silver",
        'StorageDescriptor': {
            'Columns': columns,
            'Location': s3_path,
            'InputFormat': 'org.apache.hadoop.mapred.TextInputFormat',
            'OutputFormat': 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat',
            'SerdeInfo': {
                'SerializationLibrary': 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
            }
        },
        'TableType': 'ICEBERG'
    }
    
    try:
        glue_client.update_table(
            DatabaseName=database_name,
            TableInput=table_input
        )
        print(f"Updated table {table_name}_silver in Glue Catalog")
    except glue_client.exceptions.EntityNotFoundException:
        glue_client.create_table(
            DatabaseName=database_name,
            TableInput=table_input
        )
        print(f"Created table {table_name}_silver in Glue Catalog")

def update_processing_status(table_name, layer, status, record_count, error_message=None):
    """
    Update processing status in DynamoDB control table
    """
    try:
        update_expression = "SET processing_status = :status, last_processed = :timestamp, record_count = :count"
        expression_values = {
            ':status': status,
            ':timestamp': datetime.now().isoformat(),
            ':count': record_count
        }
        
        if error_message:
            update_expression += ", error_message = :error"
            expression_values[':error'] = error_message
        
        control_table.update_item(
            Key={'table_name': table_name},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values
        )
        
        print(f"Updated processing status for {table_name}: {status}")
        
    except Exception as e:
        print(f"Error updating processing status: {str(e)}")

if __name__ == "__main__":
    process_bronze_to_silver()
    job.commit()

