
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def run_business_queries():
    # Load processed data
    dim_date_df = pd.read_csv("ambev-data-platform/docs/dim_date.csv")
    dim_product_df = pd.read_csv("ambev-data-platform/docs/dim_product.csv")
    dim_location_df = pd.read_csv("ambev-data-platform/docs/dim_location.csv")
    dim_channel_df = pd.read_csv("ambev-data-platform/docs/dim_channel.csv")
    fact_sales_df = pd.read_csv("ambev-data-platform/docs/fact_sales.csv")

    # Merge fact with dimensions for querying
    df = fact_sales_df.merge(dim_date_df, on='date_id', how='left')
    df = df.merge(dim_product_df, on='product_id', how='left')
    df = df.merge(dim_location_df, on='location_id', how='left')
    df = df.merge(dim_channel_df, on='channel_id', how='left')

    # Query 4.1: Top 3 Trade Groups (TRADE_GROUP_DESC) for each Region (Btlr_Org_LVL_C_Desc) in sales ($ Volume)
    query_4_1 = df.groupby(['Btlr_Org_LVL_C_Desc', 'TRADE_GROUP_DESC'])['$ Volume'].sum().reset_index()
    query_4_1 = query_4_1.sort_values(by=['Btlr_Org_LVL_C_Desc', '$ Volume'], ascending=[True, False])
    top_3_trade_groups = query_4_1.groupby('Btlr_Org_LVL_C_Desc').head(3)
    print("\nQuery 4.1: Top 3 Trade Groups for each Region in sales ($ Volume)")
    print(top_3_trade_groups.to_markdown(index=False))
    top_3_trade_groups.to_csv("query_4_1_results.csv", index=False)

    # Query 4.2: How much sales ($ Volume) each brand (BRAND_NM) achieved per month?
    query_4_2 = df.groupby(['BRAND_NM', 'YEAR', 'MONTH'])['$ Volume'].sum().reset_index()
    query_4_2 = query_4_2.sort_values(by=['BRAND_NM', 'YEAR', 'MONTH'])
    print("\nQuery 4.2: Sales ($ Volume) per brand per month")
    print(query_4_2.to_markdown(index=False))
    query_4_2.to_csv("query_4_2_results.csv", index=False)

    # Plot for Query 4.2
    query_4_2_data = pd.read_csv("query_4_2_results.csv")
    y_min = query_4_2_data["$ Volume"].min()
    y_max = query_4_2_data["$ Volume"].max()
    max_month = query_4_2_data["MONTH"].max()

    plt.figure(figsize=(15, 7))
    sns.lineplot(data=query_4_2_data, x='MONTH', y='$ Volume', hue='BRAND_NM', marker='o')
    plt.title('Sales ($ Volume) by Brand per Month')
    plt.xlabel('Mês')
    plt.ylabel('Volume em $')
    plt.xticks(range(1, max_month + 1))
    plt.ylim(y_min, y_max)
    plt.grid(True)
    plt.legend(title='Marca', bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.tight_layout()
    plt.savefig('sales_by_brand_per_month.png')
    plt.close()

    # Query 4.3: Which are the lowest brand (BRAND_NM) in sales ($ Volume) for each region (Btlr_Org_LVL_C_Desc)?
    query_4_3 = df.groupby(['Btlr_Org_LVL_C_Desc', 'BRAND_NM'])['$ Volume'].sum().reset_index()
    query_4_3 = query_4_3.sort_values(by=['Btlr_Org_LVL_C_Desc', '$ Volume'], ascending=[True, True])
    lowest_brand_per_region = query_4_3.groupby('Btlr_Org_LVL_C_Desc').head(1)
    print("\nQuery 4.3: Lowest Brand in sales ($ Volume) for each region")
    print(lowest_brand_per_region.to_markdown(index=False))
    lowest_brand_per_region.to_csv("query_4_3_results.csv", index=False)

    # Plot for Query 4.3
    plt.figure(figsize=(12, 6))
    sns.barplot(data=lowest_brand_per_region, x='Btlr_Org_LVL_C_Desc', y='$ Volume', hue='BRAND_NM', palette='viridis')
    plt.title('Lowest Sales Volume by Brand per Region')
    plt.xlabel('Region')
    plt.ylabel('$ Volume')
    plt.xticks(rotation=45, ha='right')
    plt.grid(axis='y', linestyle='--')
    plt.tight_layout()
    plt.savefig('lowest_brand_sales_by_region.png')
    plt.close()

if __name__ == '__main__':
    run_business_queries()



