import pandas as pd
import os

def generate_answers(sales_file, channel_group_file, output_dir):
    # Load data
    sales_df = pd.read_csv(sales_file, sep=\'\\t\')
    channel_group_df = pd.read_csv(channel_group_file)

    # Standardize column names (similar to Glue job)
    sales_df.columns = [col.lower().replace(\' \
\', \'_\').replace(\'-\
\', \'_\').replace(\'$\' , \'\').replace(\".\", \'\') for col in sales_df.columns]
    channel_group_df.columns = [col.lower().replace(\' \
\', \'_\').replace(\'-\
\', \'_\') for col in channel_group_df.columns]

    # Rename '$ volume' column to 'volume' for easier handling
    if '$ volume' in sales_df.columns:
        sales_df = sales_df.rename(columns={'volume': 'volume'})
    sales_df['volume'] = pd.to_numeric(sales_df['volume'], errors='coerce').fillna(0)

    # Merge dataframes
    merged_df = pd.merge(sales_df, channel_group_df, on='trade_chnl_desc', how='left')

    # Q4.1: Top 3 Trade Groups for each Region in sales (Volume)
    q4_1_result = merged_df.groupby(['btlr_org_lvl_c_desc', 'trade_group_desc'])['volume'].sum().reset_index()
    q4_1_result = q4_1_result.loc[q4_1_result.groupby('btlr_org_lvl_c_desc')['volume'].nlargest(3).index.get_level_values(1)]
    q4_1_result = q4_1_result.sort_values(by=['btlr_org_lvl_c_desc', 'volume'], ascending=[True, False])

    # Q4.2: How much sales (Volume) each brand (BRAND_NM) achieved per month?
    merged_df['date'] = pd.to_datetime(merged_df['date'])
    merged_df['month'] = merged_df['date'].dt.to_period('M')
    q4_2_result = merged_df.groupby(['brand_nm', 'month'])['volume'].sum().reset_index()
    q4_2_result['month'] = q4_2_result['month'].astype(str)
    q4_2_result = q4_2_result.sort_values(by=['brand_nm', 'month'])

    # Q4.3: Which are the lowest brand (BRAND_NM) in sales (Volume) for each region (Btlr_Org_LVL_C_Desc)?
    q4_3_result = merged_df.groupby(['btlr_org_lvl_c_desc', 'brand_nm'])['volume'].sum().reset_index()
    q4_3_result = q4_3_result.loc[q4_3_result.groupby('btlr_org_lvl_c_desc')['volume'].nsmallest(1).index.get_level_values(1)]
    q4_3_result = q4_3_result.sort_values(by=['btlr_org_lvl_c_desc', 'volume'])

    # Save results to markdown files
    os.makedirs(output_dir, exist_ok=True)

    with open(os.path.join(output_dir, 'business_answers.md'), 'w') as f:
        f.write("## Business Questions Answers (Based on Provided Data)\n\n")
        
        f.write("### 4.1 What are the Top 3 Trade Groups (TRADE_GROUP_DESC) for each Region (Btlr_Org_LVL_C_Desc) in sales ($ Volume)?\n")
        f.write(q4_1_result.to_markdown(index=False))
        f.write("\n\n")

        f.write("### 4.2 How much sales ($ Volume) each brand (BRAND_NM) achieved per month?\n")
        f.write(q4_2_result.to_markdown(index=False))
        f.write("\n\n")

        f.write("### 4.3 Which are the lowest brand (BRAND_NM) in sales ($ Volume) for each region (Btlr_Org_LVL_C_Desc)?\n")
        f.write(q4_3_result.to_markdown(index=False))
        f.write("\n\n")

if __name__ == '__main__':
    sales_file = '/home/ubuntu/upload/abi_bus_case1_beverage_sales_20210726.csv'
    channel_group_file = '/home/ubuntu/upload/abi_bus_case1_beverage_channel_group_20210726.csv'
    output_dir = '/home/ubuntu/ambev-data-platform/docs'
    generate_answers(sales_file, channel_group_file, output_dir)


