-- Task 4: Data Warehouse Design (Fact & Dimension Tables)


USE OlistDB
GO

-- Create a dedicated schema for the data warehouse
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dw')
BEGIN
    EXEC('CREATE SCHEMA dw')
END
GO


-- 1 - Create Dimension Tables

-- Create dim_date dimension table
IF OBJECT_ID('dw.dim_date', 'U') IS NOT NULL
    DROP TABLE dw.dim_date
GO

CREATE TABLE dw.dim_date (
    date_key INT PRIMARY KEY,  -- Surrogate key in format YYYYMMDD
    full_date DATE NOT NULL,
    day_of_week TINYINT NOT NULL,
    day_name NVARCHAR(10) NOT NULL,
    day_of_month TINYINT NOT NULL,
    day_of_year SMALLINT NOT NULL,
    week_of_year TINYINT NOT NULL,
    month_number TINYINT NOT NULL,
    month_name NVARCHAR(10) NOT NULL,
    quarter TINYINT NOT NULL,
    year SMALLINT NOT NULL,
    is_weekend BIT NOT NULL
)
GO

-- Populate the date dimension table with dates from order data
WITH DateCTE AS (
    SELECT 
        CAST(MIN(CAST(order_purchase_timestamp AS DATE)) AS DATE) AS MinDate,
        CAST(MAX(CAST(COALESCE(order_delivered_customer_date, order_estimated_delivery_date) AS DATE)) AS DATE) AS MaxDate
    FROM dbo.olist_orders
),
DateRange AS (
    SELECT 
        DATEADD(DAY, number, MinDate) AS FullDate
    FROM 
        DateCTE
        CROSS JOIN master.dbo.spt_values
    WHERE 
        type = 'P' 
        AND number <= DATEDIFF(DAY, MinDate, MaxDate)
)
INSERT INTO dw.dim_date (
    date_key,
    full_date,
    day_of_week,
    day_name,
    day_of_month,
    day_of_year,
    week_of_year,
    month_number,
    month_name,
    quarter,
    year,
    is_weekend
)
SELECT
    CAST(CONVERT(VARCHAR, FullDate, 112) AS INT) AS date_key,
    FullDate AS full_date,
    DATEPART(WEEKDAY, FullDate) AS day_of_week,
    DATENAME(WEEKDAY, FullDate) AS day_name,
    DAY(FullDate) AS day_of_month,
    DATEPART(DAYOFYEAR, FullDate) AS day_of_year,
    DATEPART(WEEK, FullDate) AS week_of_year,
    MONTH(FullDate) AS month_number,
    DATENAME(MONTH, FullDate) AS month_name,
    DATEPART(QUARTER, FullDate) AS quarter,
    YEAR(FullDate) AS year,
    CASE WHEN DATEPART(WEEKDAY, FullDate) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM DateRange
ORDER BY FullDate
GO

-- Create dim_customers dimension table
IF OBJECT_ID('dw.dim_customers', 'U') IS NOT NULL
    DROP TABLE dw.dim_customers
GO

CREATE TABLE dw.dim_customers (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_id NVARCHAR(255) NOT NULL,
    customer_unique_id NVARCHAR(255) NOT NULL,
    customer_zip_code_prefix NVARCHAR(20) NOT NULL,
    customer_city NVARCHAR(100) NOT NULL,
    customer_state NVARCHAR(2) NOT NULL
)
GO

-- Populate the customers dimension with data from the source table
INSERT INTO dw.dim_customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT DISTINCT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state
FROM dbo.olist_customers c
GO

-- Create dim_products dimension table
IF OBJECT_ID('dw.dim_products', 'U') IS NOT NULL
    DROP TABLE dw.dim_products
GO

CREATE TABLE dw.dim_products (
    product_key INT IDENTITY(1,1) PRIMARY KEY,
    product_id NVARCHAR(255) NOT NULL,
    product_category_name NVARCHAR(100) NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL
)
GO

-- Populate the products dimension with data from the source table
INSERT INTO dw.dim_products (
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT DISTINCT
    p.product_id,
    p.product_category_name,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM dbo.olist_products p
GO

-- Create dim_sellers dimension table
IF OBJECT_ID('dw.dim_sellers', 'U') IS NOT NULL
    DROP TABLE dw.dim_sellers
GO

CREATE TABLE dw.dim_sellers (
    seller_key INT IDENTITY(1,1) PRIMARY KEY,
    seller_id NVARCHAR(255) NOT NULL,
    seller_zip_code_prefix NVARCHAR(20) NOT NULL,
    seller_city NVARCHAR(100) NOT NULL,
    seller_state NVARCHAR(2) NOT NULL
)
GO

-- Populate the sellers dimension with data from the source table
INSERT INTO dw.dim_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT DISTINCT
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state
FROM dbo.olist_sellers s
GO



-- 2 - Create Fact Table

-- Create fact_order_items fact table
IF OBJECT_ID('dw.fact_order_items', 'U') IS NOT NULL
    DROP TABLE dw.fact_order_items
GO

CREATE TABLE dw.fact_order_items (
    order_item_key BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_id NVARCHAR(255) NOT NULL,
    order_item_id INT NOT NULL,
    -- Foreign keys to dimension tables
    customer_key INT NOT NULL,
    product_key INT NOT NULL,
    seller_key INT NOT NULL,
    -- Required attributes from task
    product_id NVARCHAR(255) NOT NULL,
    seller_id NVARCHAR(255) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    -- Metrics and measures
    product_price DECIMAL(18, 2) NOT NULL,
    freight_value DECIMAL(18, 2) NOT NULL,
    total_price DECIMAL(18, 2) NOT NULL,
    delivery_time_days INT NULL,
    profit_margin DECIMAL(18, 2) NOT NULL,
    -- Constraints
    CONSTRAINT UQ_fact_order_items UNIQUE (order_id, order_item_id)
)
GO

-- Populate the fact table
INSERT INTO dw.fact_order_items (
    order_id,
    order_item_id,
    customer_key,
    product_key,
    seller_key,
    product_id,
    seller_id,
    shipping_limit_date,
    product_price,
    freight_value,
    total_price,
    delivery_time_days,
    profit_margin
)
SELECT
    oi.order_id,
    oi.order_item_id,
    dc.customer_key,
    dp.product_key,
    ds.seller_key,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price AS product_price,
    oi.freight_value,
    (oi.price + oi.freight_value) AS total_price,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_time_days,
    (oi.price - oi.freight_value) AS profit_margin
FROM 
    dbo.olist_order_items oi
JOIN 
    dbo.olist_orders o ON oi.order_id = o.order_id
JOIN 
    dw.dim_customers dc ON o.customer_id = dc.customer_id
JOIN 
    dw.dim_products dp ON oi.product_id = dp.product_id
JOIN 
    dw.dim_sellers ds ON oi.seller_id = ds.seller_id
GO

-- Add foreign key constraints
ALTER TABLE dw.fact_order_items 
ADD CONSTRAINT FK_fact_order_items_dim_customers
FOREIGN KEY (customer_key) REFERENCES dw.dim_customers(customer_key)
GO

ALTER TABLE dw.fact_order_items 
ADD CONSTRAINT FK_fact_order_items_dim_products
FOREIGN KEY (product_key) REFERENCES dw.dim_products(product_key)
GO

ALTER TABLE dw.fact_order_items 
ADD CONSTRAINT FK_fact_order_items_dim_sellers
FOREIGN KEY (seller_key) REFERENCES dw.dim_sellers(seller_key)
GO



-- 3 - Verify Data Warehouse Setup

-- Check dimension table row counts
SELECT 'dim_customers' AS table_name, COUNT(*) AS [row_count] FROM dw.dim_customers
UNION ALL
SELECT 'dim_products', COUNT(*) FROM dw.dim_products
UNION ALL
SELECT 'dim_sellers', COUNT(*) FROM dw.dim_sellers
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dw.dim_date
UNION ALL
SELECT 'fact_order_items', COUNT(*) FROM dw.fact_order_items
GO