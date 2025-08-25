-- Business Question 4.1
-- What are the Top 3 Trade Groups (TRADE_GROUP_DESC) for each Region (Btlr_Org_LVL_C_Desc) in sales ($ Volume)?
WITH RegionalSales AS (
    SELECT
        dr.btlr_org_lvl_c_desc AS Region,
        dtg.trade_group_desc AS TradeGroup,
        SUM(fs.volume) AS TotalSalesVolume
    FROM
        gold_db.fact_sales fs
    JOIN
        gold_db.dim_region dr ON fs.region_key = dr.region_key
    JOIN
        gold_db.dim_trade_group dtg ON fs.trade_group_key = dtg.trade_group_key
    GROUP BY
        dr.btlr_org_lvl_c_desc,
        dtg.trade_group_desc
),
RankedRegionalSales AS (
    SELECT
        Region,
        TradeGroup,
        TotalSalesVolume,
        ROW_NUMBER() OVER (PARTITION BY Region ORDER BY TotalSalesVolume DESC) as rn
    FROM
        RegionalSales
)
SELECT
    Region,
    TradeGroup,
    TotalSalesVolume
FROM
    RankedRegionalSales
WHERE
    rn <= 3
ORDER BY
    Region,
    TotalSalesVolume DESC;

-- Business Question 4.2
-- How much sales ($ Volume) each brand (BRAND_NM) achieved per month?
SELECT
    db.brand_nm AS BrandName,
    dt.year AS SalesYear,
    dt.month_name AS SalesMonth,
    SUM(fs.volume) AS TotalSalesVolume
FROM
    gold_db.fact_sales fs
JOIN
    gold_db.dim_brand db ON fs.brand_key = db.brand_key
JOIN
    gold_db.dim_time dt ON fs.date_key = dt.date_key
GROUP BY
    db.brand_nm,
    dt.year,
    dt.month_name
ORDER BY
    db.brand_nm,
    dt.year,
    dt.month;

-- Business Question 4.3
-- Which are the lowest brand (BRAND_NM) in sales ($ Volume) for each region (Btlr_Org_LVL_C_Desc)?
WITH RegionalBrandSales AS (
    SELECT
        dr.btlr_org_lvl_c_desc AS Region,
        db.brand_nm AS BrandName,
        SUM(fs.volume) AS TotalSalesVolume
    FROM
        gold_db.fact_sales fs
    JOIN
        gold_db.dim_region dr ON fs.region_key = dr.region_key
    JOIN
        gold_db.dim_brand db ON fs.brand_key = db.brand_key
    GROUP BY
        dr.btlr_org_lvl_c_desc,
        db.brand_nm
),
RankedLowestRegionalBrandSales AS (
    SELECT
        Region,
        BrandName,
        TotalSalesVolume,
        ROW_NUMBER() OVER (PARTITION BY Region ORDER BY TotalSalesVolume ASC) as rn
    FROM
        RegionalBrandSales
)
SELECT
    Region,
    BrandName,
    TotalSalesVolume
FROM
    RankedLowestRegionalBrandSales
WHERE
    rn = 1
ORDER BY
    Region,
    TotalSalesVolume ASC;


