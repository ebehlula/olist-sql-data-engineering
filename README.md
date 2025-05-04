# Olist E-commerce Data Engineering Project

## Overview
This repository contains SQL scripts implementing a complete data engineering solution for the Olist e-commerce dataset. The project demonstrates data loading, transformation, business calculations, and dimensional modeling.

## Task Structure
The repository is organized into five main SQL scripts corresponding to the project tasks:

- `task1_data_loading.sql`: Data extraction and cleaning pipeline
- `task2_calculated_columns.sql`: Business calculation implementations
- `task3_window_functions.sql`: Advanced analytical functions
- `task4_data_warehouse.sql`: Star schema implementation
- `task5_reporting.sql`: Validation and business reports

## Implementation Details

### Task 1: Data Loading and Cleaning
Created a two-phase ETL process with staging and production schemas, along with a reusable procedure for CSV loading:

```sql
CREATE OR ALTER PROCEDURE stg.LoadCSVFile
    @TableName NVARCHAR(255),
    @FilePath NVARCHAR(1000),
    @HasHeaderRow BIT = 1,
    @FieldTerminator NVARCHAR(10) = ',',
    @RowTerminator NVARCHAR(10) = '0x0a'
AS
BEGIN
    -- Implementation details
END
```
## Task 2: Creating Calculated Columns
Implemented business calculations through multiple approaches:
```sql
-- View approach
CREATE OR ALTER VIEW dbo.vw_order_items_calculated AS
SELECT 
    oi.order_id,
    oi.order_item_id,
    (oi.price + oi.freight_value) AS total_price,
    (oi.price - oi.freight_value) AS profit_margin
FROM dbo.olist_order_items oi
```

## Task 3: Window Functions
Used partitioning for advanced analytics:
```sql
SELECT 
    o.customer_id,
    oi.order_id,
    SUM(oi.price) OVER(
        PARTITION BY o.customer_id 
        ORDER BY o.order_purchase_timestamp
    ) AS running_total
FROM dbo.olist_order_items oi
JOIN dbo.olist_orders o ON oi.order_id = o.order_id
```

## Task 4: Data Warehouse
Implemented a star schema with dimension and fact tables:
```sql
CREATE TABLE dw.fact_order_items (
    order_item_key BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_id NVARCHAR(255) NOT NULL,
    customer_key INT NOT NULL,
    product_key INT NOT NULL,
    seller_key INT NOT NULL,
    product_price DECIMAL(18, 2) NOT NULL,
    freight_value DECIMAL(18, 2) NOT NULL,
    total_price DECIMAL(18, 2) NOT NULL
)
```

## Task 5: Reporting
Created validation queries and business reports:
```sql
SELECT 
    dp.product_category_name, 
    SUM(f.total_price) AS total_sales
FROM dw.fact_order_items f
JOIN dw.dim_products dp ON f.product_key = dp.product_key
GROUP BY dp.product_category_name
ORDER BY total_sales DESC
```

## Summary
This project required me to develop a comprehensive SQL Server solution for processing e-commerce data across five key tasks: data loading and cleaning, business calculations, window function analytics, dimensional modeling, and reporting.
To meet these requirements, I implemented a multi-phased solution that began with a robust ETL pipeline using staging tables and parameterized stored procedures for data loading. I demonstrated four different approaches to business calculations (views, materialized tables, computed columns, and indexed views) to show their relative advantages. For analytics, I leveraged window functions to efficiently calculate running totals and moving averages without complex self-joins. I designed a star schema data warehouse with dimension and fact tables optimized for analytical queries, featuring surrogate keys and proper constraints. Finally, I validated the solution with reporting queries that demonstrate practical business insights.
The final solution incorporates SQL best practices including error handling, performance optimization through strategic indexing, and separation of concerns through schema design. This implementation transforms raw transactional data into a structured analytical framework ready for business intelligence applications.

## Setup Instructions
- Create a SQL Server database.
- Execute the scripts in numerical order.
- Adjust file paths in Task 1 to match your environment.

## Requirements
- Microsoft SQL Server 2016 or later
- Olist dataset CSV files

## Setup Instructions

1. Create a SQL Server database
2. Either:
   - Execute the scripts in numerical order (if you want to build the database from scratch)
   - [Restore the complete database backup](https://drive.google.com/drive/u/0/folders/1PHAmU2EV_skjYXZZ1VM_5fDOvChlIkfb) (fastest option)
3. Adjust file paths in Task 1 to match your environment
