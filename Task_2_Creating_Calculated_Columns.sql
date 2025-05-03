-- Task 2: Creating Calculated Columns

USE OlistDB;
GO


-- 1 - Create a view with all calculated columns

CREATE OR ALTER VIEW dbo.vw_order_items_calculated AS
SELECT 
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price AS product_price,
    oi.freight_value,
    (oi.price + oi.freight_value) AS total_price,
    (oi.price - oi.freight_value) AS profit_margin,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_time_days,
    (
        SELECT SUM(payment_installments) 
        FROM dbo.olist_order_payments op 
        WHERE op.order_id = oi.order_id
    ) AS payment_count
FROM 
    dbo.olist_order_items oi
LEFT JOIN 
    dbo.olist_orders o ON oi.order_id = o.order_id;
GO

-- Test the view
SELECT TOP 100 * 
FROM dbo.vw_order_items_calculated
GO


-- 2 - Create a new table with calculated columns

-- Create a new table with calculated columns
IF OBJECT_ID('dbo.order_items_with_calculations', 'U') IS NOT NULL
    DROP TABLE dbo.order_items_with_calculations;
GO

CREATE TABLE dbo.order_items_with_calculations (
    order_id NVARCHAR(255) NOT NULL,
    order_item_id INT NOT NULL,
    product_id NVARCHAR(255) NOT NULL,
    seller_id NVARCHAR(255) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    product_price DECIMAL(18, 2) NOT NULL,
    freight_value DECIMAL(18, 2) NOT NULL,
    total_price DECIMAL(18, 2) NOT NULL,
    profit_margin DECIMAL(18, 2) NOT NULL,
    delivery_time_days INT NULL,
    payment_count INT NULL,
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE(),
    CONSTRAINT PK_order_items_with_calculations PRIMARY KEY CLUSTERED (order_id, order_item_id)
);
GO

-- Create supporting indexes
CREATE NONCLUSTERED INDEX IX_order_items_with_calculations_product
ON dbo.order_items_with_calculations(product_id);
GO

CREATE NONCLUSTERED INDEX IX_order_items_with_calculations_seller
ON dbo.order_items_with_calculations(seller_id);
GO

-- Populate with data
INSERT INTO dbo.order_items_with_calculations (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    product_price,
    freight_value,
    total_price,
    profit_margin,
    delivery_time_days,
    payment_count
)
SELECT 
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price AS product_price,
    oi.freight_value,
    (oi.price + oi.freight_value) AS total_price,
    (oi.price - oi.freight_value) AS profit_margin,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_time_days,
    (
        SELECT SUM(payment_installments) 
        FROM dbo.olist_order_payments op 
        WHERE op.order_id = oi.order_id
    ) AS payment_count
FROM 
    dbo.olist_order_items oi
LEFT JOIN 
    dbo.olist_orders o ON oi.order_id = o.order_id;
GO

-- Test the new table
SELECT TOP 100 * 
FROM dbo.order_items_with_calculations
GO



-- 3 - Add calculated columns to existing table

-- Add calc_total_price column
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.olist_order_items') AND name = 'calc_total_price')
BEGIN
    -- Add the calculated column
    ALTER TABLE dbo.olist_order_items 
    ADD calc_total_price AS (price + freight_value) PERSISTED;
    
    PRINT 'Added calc_total_price column';
END
GO

-- Add calc_profit_margin column
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.olist_order_items') AND name = 'calc_profit_margin')
BEGIN
    -- Add the calculated column
    ALTER TABLE dbo.olist_order_items 
    ADD calc_profit_margin AS (price - freight_value) PERSISTED;
    
    PRINT 'Added calc_profit_margin column';
END
GO

-- Add calc_delivery_time_days column
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.olist_order_items') AND name = 'calc_delivery_time_days')
BEGIN
    -- Add the regular column
    ALTER TABLE dbo.olist_order_items 
    ADD calc_delivery_time_days INT NULL;
    
    PRINT 'Added calc_delivery_time_days column';
END
GO

-- Update delivery time days values
UPDATE oi
SET calc_delivery_time_days = DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)
FROM dbo.olist_order_items oi
JOIN dbo.olist_orders o ON oi.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL;
    
PRINT 'Updated calc_delivery_time_days values';
GO


USE OlistDB;
GO
-- Add calc_payment_count column
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.olist_order_items') AND name = 'calc_payment_count')
BEGIN
    -- Add the regular column
    ALTER TABLE dbo.olist_order_items 
    ADD calc_payment_count INT NULL;
    
    PRINT 'Added calc_payment_count column';
END
GO

-- Update payment count values
UPDATE oi
SET calc_payment_count = payment_sums.total_installments
FROM dbo.olist_order_items oi
JOIN (
    SELECT 
        order_id, 
        SUM(payment_installments) AS total_installments
    FROM 
        dbo.olist_order_payments
    GROUP BY 
        order_id
) AS payment_sums ON oi.order_id = payment_sums.order_id;
    
PRINT 'Updated calc_payment_count values';
GO



-- 4 - Create an indexed view


IF OBJECT_ID('dbo.vw_order_items_indexed', 'V') IS NOT NULL
    DROP VIEW dbo.vw_order_items_indexed;
GO

CREATE VIEW dbo.vw_order_items_indexed
WITH SCHEMABINDING
AS
SELECT 
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price AS product_price,
    oi.freight_value,
    (oi.price + oi.freight_value) AS calculated_total_price,
    (oi.price - oi.freight_value) AS calculated_profit_margin
FROM 
    dbo.olist_order_items oi;
GO

-- Create a unique clustered index on the view
CREATE UNIQUE CLUSTERED INDEX IX_vw_order_items_indexed
ON dbo.vw_order_items_indexed(order_id, order_item_id);
GO




-- Verify implementations


-- Test all approaches
SELECT 'View Approach' AS Method, COUNT(*) AS RecordCount FROM dbo.vw_order_items_calculated
UNION ALL
SELECT 'New Table Approach', COUNT(*) FROM dbo.order_items_with_calculations
UNION ALL
SELECT 'Existing Table with Calc Columns', COUNT(*) FROM dbo.olist_order_items
UNION ALL
SELECT 'Indexed View Approach', COUNT(*) FROM dbo.vw_order_items_indexed;
GO