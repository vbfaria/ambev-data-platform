# Business Questions and Answers - Real Data Analysis

This document provides answers to the three key business questions using the processed data from the Ambev beverage sales dataset.

## Data Processing Summary

The analysis was performed on the following datasets:
- **Sales Data**: `abi_bus_case1_beverage_sales_20210726.csv` (16,152 records)
- **Channel Data**: `abi_bus_case1_beverage_channel_group_20210726.csv` (32 records)

### Data Quality Notes:
- **Negative Sales**: 1,856 records with negative sales volume were found and included in the analysis
- **Data Cleaning**: Duplicates removed, null values handled, and proper data types enforced
- **Dimensional Modeling**: Data transformed into Star Schema with fact and dimension tables

## Business Question 4.1: Top 3 Trade Groups by Region

**Question**: What are the Top 3 Trade Groups (TRADE_GROUP_DESC) for each Region (Btlr_Org_LVL_C_Desc) in sales ($ Volume)?

### Answer:

| Region        | Trade Group | Total Sales Volume |
|---------------|-------------|-------------------|
| CANADA        | GROCERY     | 1,227,020         |
| CANADA        | SERVICES    | 589,527           |
| CANADA        | ACADEMIC    | 377,970           |
| GREAT LAKES   | GROCERY     | 2,721,250         |
| GREAT LAKES   | SERVICES    | 1,119,510         |
| GREAT LAKES   | ACADEMIC    | 1,071,100         |
| MIDWEST       | GROCERY     | 2,345,230         |
| MIDWEST       | SERVICES    | 918,789           |
| MIDWEST       | ACADEMIC    | 627,038           |
| NORTHEAST     | GROCERY     | 2,912,660         |
| NORTHEAST     | SERVICES    | 1,115,670         |
| NORTHEAST     | ACADEMIC    | 1,057,640         |
| SOUTHEAST     | GROCERY     | 3,005,890         |
| SOUTHEAST     | SERVICES    | 1,602,870         |
| SOUTHEAST     | ACADEMIC    | 896,673           |
| SOUTHWEST     | GROCERY     | 1,964,560         |
| SOUTHWEST     | SERVICES    | 1,124,590         |
| SOUTHWEST     | ACADEMIC    | 549,242           |
| WEST          | GROCERY     | 1,471,110         |
| WEST          | SERVICES    | 629,711           |
| WEST          | ACADEMIC    | 560,010           |

### Key Insights:
- **GROCERY** dominates all regions, representing the largest sales volume across all geographic areas
- **SERVICES** consistently ranks second in all regions
- **ACADEMIC** holds the third position in all regions
- **SOUTHEAST** shows the highest total sales volume, followed by **NORTHEAST** and **GREAT LAKES**

## Business Question 4.2: Sales by Brand per Month

**Question**: How much sales ($ Volume) each brand (BRAND_NM) achieved per month?

### Answer:

| Brand      | Year | Month | Sales Volume |
|------------|------|-------|-------------|
| GRAPE      | 2006 | 3     | 7.5         |
| LEMON      | 2006 | 1     | 4,046,760   |
| LEMON      | 2006 | 2     | 4,407,530   |
| LEMON      | 2006 | 3     | 6,127,540   |
| RASPBERRY  | 2006 | 1     | 2,747,860   |
| RASPBERRY  | 2006 | 2     | 2,867,630   |
| RASPBERRY  | 2006 | 3     | 4,112,660   |
| STRAWBERRY | 2006 | 1     | 1,895,420   |
| STRAWBERRY | 2006 | 2     | 2,073,110   |
| STRAWBERRY | 2006 | 3     | 2,850,190   |

### Key Insights:
- **LEMON** is the top-performing brand with consistent growth from January to March 2006
- **RASPBERRY** shows strong performance and growth trajectory
- **STRAWBERRY** has the lowest overall performance but shows steady month-over-month growth
- **GRAPE** appears only in March with minimal sales volume (7.5)
- All brands show positive growth trends from January to March 2006

## Business Question 4.3: Lowest Brand by Region

**Question**: Which are the lowest brand (BRAND_NM) in sales ($ Volume) for each region (Btlr_Org_LVL_C_Desc)?

### Answer:

| Region        | Brand      | Sales Volume |
|---------------|------------|-------------|
| CANADA        | STRAWBERRY | 444,058     |
| GREAT LAKES   | STRAWBERRY | 1,252,490   |
| MIDWEST       | STRAWBERRY | 895,241     |
| NORTHEAST     | STRAWBERRY | 1,173,490   |
| SOUTHEAST     | STRAWBERRY | 1,399,960   |
| SOUTHWEST     | GRAPE      | 7.5         |
| WEST          | STRAWBERRY | 807,067     |

### Key Insights:
- **STRAWBERRY** is the lowest-performing brand in 6 out of 7 regions
- **GRAPE** is the lowest-performing brand only in **SOUTHWEST** with extremely low sales (7.5)
- **STRAWBERRY** performance varies significantly by region, with **SOUTHEAST** showing the highest volume among the lowest performers
- **SOUTHWEST** presents a unique case with **GRAPE** having minimal market presence
- This indicates potential opportunities for targeted marketing and distribution strategies for these underperforming brands

## Strategic Recommendations

Based on these findings, Ambev should consider:

1. **Channel Strategy**: Leverage the strong **GROCERY** channel performance while exploring growth opportunities in **SERVICES** and **ACADEMIC** channels

2. **Brand Portfolio Optimization**: 
   - Investigate the causes of **STRAWBERRY** underperformance across multiple regions
   - Develop specific strategies for **GRAPE** brand, particularly in the **SOUTHWEST** region

3. **Regional Focus**: 
   - **SOUTHEAST** and **NORTHEAST** show strong overall performance and could be models for other regions
   - **CANADA** and **WEST** may need additional support to improve overall sales volume

4. **Seasonal Planning**: The month-over-month growth patterns suggest effective seasonal strategies that could be replicated and enhanced

