
import pandas as pd

def process_sales_data(sales_file_path, channel_file_path):
    sales_df = pd.read_csv(sales_file_path, sep='\t')
    channel_df = pd.read_csv(channel_file_path)

    sales_df.columns = sales_df.columns.str.strip()
    sales_df = sales_df.drop_duplicates()
    sales_df = sales_df.dropna(subset=['DATE', 'BRAND_NM', 'Btlr_Org_LVL_C_Desc', 'CHNL_GROUP', '$ Volume'])

    sales_df['$ Volume'] = pd.to_numeric(sales_df['$ Volume'], errors='coerce')
    sales_df = sales_df.dropna(subset=['$ Volume'])

    sales_df['DATE'] = pd.to_datetime(sales_df['DATE'], errors='coerce')
    sales_df = sales_df.dropna(subset=['DATE'])

    channel_df.columns = channel_df.columns.str.strip()
    channel_df = channel_df.drop_duplicates()
    channel_df = channel_df.dropna(subset=['TRADE_CHNL_DESC', 'TRADE_GROUP_DESC', 'TRADE_TYPE_DESC'])

    # Create Dimension Tables
    # Dim_Date
    dim_date = sales_df[['DATE', 'YEAR', 'MONTH', 'PERIOD']].drop_duplicates().reset_index(drop=True)
    dim_date['date_id'] = dim_date.index

    # Dim_Product
    dim_product = sales_df[['CE_BRAND_FLVR', 'BRAND_NM', 'PKG_CAT', 'Pkg_Cat_Desc', 'TSR_PCKG_NM']].drop_duplicates().reset_index(drop=True)
    dim_product['product_id'] = dim_product.index

    # Dim_Location
    dim_location = sales_df[['Btlr_Org_LVL_C_Desc']].drop_duplicates().reset_index(drop=True)
    dim_location['location_id'] = dim_location.index

    # Dim_Channel
    dim_channel = channel_df[['TRADE_CHNL_DESC', 'TRADE_GROUP_DESC', 'TRADE_TYPE_DESC']].drop_duplicates().reset_index(drop=True)
    dim_channel['channel_id'] = dim_channel.index

    # Create Fact Table
    fact_sales = sales_df.merge(dim_date[['DATE', 'date_id']], on='DATE', how='left')
    fact_sales = fact_sales.merge(dim_product[['CE_BRAND_FLVR', 'BRAND_NM', 'product_id']], on=['CE_BRAND_FLVR', 'BRAND_NM'], how='left')
    fact_sales = fact_sales.merge(dim_location[['Btlr_Org_LVL_C_Desc', 'location_id']], on='Btlr_Org_LVL_C_Desc', how='left')
    fact_sales = fact_sales.merge(dim_channel[['TRADE_CHNL_DESC', 'channel_id']], on='TRADE_CHNL_DESC', how='left')

    fact_sales = fact_sales[['date_id', 'product_id', 'location_id', 'channel_id', '$ Volume']]

    # Handle potential inconsistencies/anomalies 
    negative_sales_count = fact_sales[fact_sales['$ Volume'] < 0].shape[0]
    if negative_sales_count > 0:
        print(f"Warning: {negative_sales_count} records with negative sales volume found. These will be included in the fact table.")

    return dim_date, dim_product, dim_location, dim_channel, fact_sales

if __name__ == '__main__':
    sales_file = 'ambev-data-platform/inputs/abi_bus_case1_beverage_sales_20210726.csv'
    channel_file = 'ambev-data-platform/inputs/abi_bus_case1_beverage_channel_group_20210726.csv'
    dim_date_df, dim_product_df, dim_location_df, dim_channel_df, fact_sales_df = process_sales_data(sales_file, channel_file)

    dim_date_df.to_csv('dim_date.csv', index=False)
    dim_product_df.to_csv('dim_product.csv', index=False)
    dim_location_df.to_csv('dim_location.csv', index=False)
    dim_channel_df.to_csv('dim_channel.csv', index=False)
    fact_sales_df.to_csv('fact_sales.csv', index=False)

    print("Data processing complete. Dimension and Fact tables saved as CSVs.")


