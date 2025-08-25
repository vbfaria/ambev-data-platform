import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, monotonically_increasing_id, lit

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'source_path',
    'target_fact_path',
    'target_dim_time_path',
    'target_dim_brand_path',
    'target_dim_trade_group_path',
    'target_dim_region_path',
    'silver_database_name',
    'gold_database'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Read data from Silver layer (assuming 'sales' table in Silver DB)
dataset = glueContext.create_dynamic_frame.from_catalog(
    database=args['silver_database_name'],
    table_name='sales_silver',
    transformation_ctx="silver_source"
)

df = dataset.toDF()

# --- Dimensional Model Transformation ---
# Create Dimension Tables 
# Dim Time
dim_time_df = df.select(
    col("date").alias("date"),
    col("year").alias("year"),
    col("month").alias("month")
).distinct()

# Add a surrogate key for dim_time
dim_time_df = dim_time_df.withColumn("date_key", monotonically_increasing_id())

# Dim Brand
dim_brand_df = df.select(
    col("brand_nm").alias("brand_nm"),
    # Add other brand attributes if available
).distinct()

# Add a surrogate key for dim_brand
dim_brand_df = dim_brand_df.withColumn("brand_key", monotonically_increasing_id())

# Dim Trade Group
dim_trade_group_df = df.select(
    col("trade_group_desc").alias("trade_group_desc"),
    # Add other trade group attributes if available
).distinct()

# Add a surrogate key for dim_trade_group
dim_trade_group_df = dim_trade_group_df.withColumn("trade_group_key", monotonically_increasing_id())

# Dim Region
dim_region_df = df.select(
    col("btlr_org_lvl_c_desc").alias("btlr_org_lvl_c_desc"),
    # Add other region attributes if available
).distinct()

# Add a surrogate key for dim_region
dim_region_df = dim_region_df.withColumn("region_key", monotonically_increasing_id())

# Fact Sales Table

fact_sales_df = df.join(dim_time_df, on=["date", "year", "month"], how="left") \
                  .join(dim_brand_df, on=["brand_nm"], how="left") \
                  .join(dim_trade_group_df, on=["trade_group_desc"], how="left") \
                  .join(dim_region_df, on=["btlr_org_lvl_c_desc"], how="left") \
                  .select(
                      monotonically_increasing_id().alias("sales_id"), # Fact table surrogate key
                      col("date_key"),
                      col("brand_key"),
                      col("trade_group_key"),
                      col("region_key"),
                      col("volume").alias("volume")
                  )

# Write Dimension Tables to Gold Layer (Iceberg format)
# Note: For Iceberg, you typically write using Spark SQL or Iceberg API directly
# This is a conceptual representation of writing to S3 in Iceberg format

dim_time_df.write.format("iceberg").mode("overwrite").save(args["target_dim_time_path"])
dim_brand_df.write.format("iceberg").mode("overwrite").save(args["target_dim_brand_path"])
dim_trade_group_df.write.format("iceberg").mode("overwrite").save(args["target_dim_trade_group_path"])
dim_region_df.write.format("iceberg").mode("overwrite").save(args["target_dim_region_path"])

# Write Fact Table to Gold Layer (Iceberg format)
fact_sales_df.write.format("iceberg").mode("overwrite").save(args["target_fact_path"])

job.commit()

