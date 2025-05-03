-- Task 3: SQL Window Functions


-- 1 - TotalSalesPerCustomer: Running total of product_price partitioned by customer_id

USE OlistDB
GO

-- Using a Common Table Expression (CTE)
WITH CustomerOrdersWithTotals AS (
    SELECT 
        o.customer_id,
        o.order_id,
        oi.product_id,
        oi.price AS product_price,
        -- Running total of product price by customer
        SUM(oi.price) OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.order_purchase_timestamp, o.order_id, oi.order_item_id
            ROWS UNBOUNDED PRECEDING
        ) AS running_total_sales,
        -- Rank orders by price within each customer
        RANK() OVER (
            PARTITION BY o.customer_id 
            ORDER BY oi.price DESC
        ) AS price_rank,
        -- Row number to identify purchase sequence
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.order_purchase_timestamp
        ) AS purchase_sequence
    FROM 
        dbo.olist_orders o
    JOIN 
        dbo.olist_order_items oi ON o.order_id = oi.order_id
)
-- Select from the CTE
SELECT TOP 100
    customer_id,
    order_id,
    product_id,
    product_price,
    running_total_sales,
    price_rank,
    purchase_sequence
FROM 
    CustomerOrdersWithTotals
ORDER BY 
    customer_id, 
    purchase_sequence
GO

-- Create a view access information
CREATE OR ALTER VIEW dbo.vw_customer_sales_analysis AS
SELECT 
    o.customer_id,
    c.customer_state,
    c.customer_city,
    o.order_id,
    o.order_purchase_timestamp,
    oi.product_id,
    p.product_category_name,
    oi.price AS product_price,
    -- Running total of product price by customer
    SUM(oi.price) OVER (
        PARTITION BY o.customer_id 
        ORDER BY o.order_purchase_timestamp, o.order_id, oi.order_item_id
        ROWS UNBOUNDED PRECEDING
    ) AS running_total_sales,
    -- Total sales per customer (to compare running total with final total)
    SUM(oi.price) OVER (
        PARTITION BY o.customer_id
    ) AS customer_total_sales,
    -- Rank products by price within each customer
    RANK() OVER (
        PARTITION BY o.customer_id 
        ORDER BY oi.price DESC
    ) AS price_rank,
    -- Row number to identify purchase sequence
    ROW_NUMBER() OVER (
        PARTITION BY o.customer_id 
        ORDER BY o.order_purchase_timestamp, o.order_id, oi.order_item_id
    ) AS purchase_sequence
FROM 
    dbo.olist_orders o
JOIN 
    dbo.olist_order_items oi ON o.order_id = oi.order_id
JOIN 
    dbo.olist_customers c ON o.customer_id = c.customer_id
LEFT JOIN 
    dbo.olist_products p ON oi.product_id = p.product_id
GO

-- Test the view
SELECT TOP 100 * 
FROM dbo.vw_customer_sales_analysis
ORDER BY customer_id, purchase_sequence
GO



-- 2 - AvgDeliveryTimePerCategory: Rolling average delivery time partitioned by product_category_name

-- Define a CTE for delivery times by product category
WITH CategoryDeliveryTimes AS (
    SELECT 
        p.product_category_name,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        -- Calculate delivery time in days
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_time_days,
        -- Row number within category ordered by timestamp
        ROW_NUMBER() OVER (
            PARTITION BY p.product_category_name 
            ORDER BY o.order_purchase_timestamp
        ) AS category_order_sequence
    FROM 
        dbo.olist_products p
    JOIN 
        dbo.olist_order_items oi ON p.product_id = oi.product_id
    JOIN 
        dbo.olist_orders o ON oi.order_id = o.order_id
    WHERE 
        p.product_category_name IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
)
-- Calculate rolling averages with various window sizes
SELECT TOP 500
    product_category_name,
    order_id,
    order_purchase_timestamp,
    delivery_time_days,
    category_order_sequence,
    -- Simple average of all deliveries in this category
    AVG(delivery_time_days) OVER (
        PARTITION BY product_category_name
    ) AS category_avg_delivery_days,
    -- Rolling average of last 3 deliveries in this category
    AVG(delivery_time_days) OVER (
        PARTITION BY product_category_name 
        ORDER BY order_purchase_timestamp
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_3_deliveries,
    -- Rolling average of last 7 deliveries in this category
    AVG(delivery_time_days) OVER (
        PARTITION BY product_category_name 
        ORDER BY order_purchase_timestamp
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_7_deliveries,
    -- Rolling average of all previous deliveries including current
    AVG(delivery_time_days) OVER (
        PARTITION BY product_category_name 
        ORDER BY order_purchase_timestamp
        ROWS UNBOUNDED PRECEDING
    ) AS rolling_avg_all_previous,
    -- Minimum delivery time in this category
    MIN(delivery_time_days) OVER (
        PARTITION BY product_category_name
    ) AS min_delivery_days,
    -- Maximum delivery time in this category
    MAX(delivery_time_days) OVER (
        PARTITION BY product_category_name
    ) AS max_delivery_days
FROM 
    CategoryDeliveryTimes
ORDER BY 
    product_category_name, 
    order_purchase_timestamp
GO

-- Create a view for category delivery time analysis
CREATE OR ALTER VIEW dbo.vw_category_delivery_analysis AS
WITH CategoryDeliveryBase AS (
    SELECT 
        COALESCE(p.product_category_name, 'Unknown') AS product_category_name,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        -- Calculate delivery time in days
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_time_days
    FROM 
        dbo.olist_products p
    JOIN 
        dbo.olist_order_items oi ON p.product_id = oi.product_id
    JOIN 
        dbo.olist_orders o ON oi.order_id = o.order_id
    WHERE 
        o.order_delivered_customer_date IS NOT NULL
)
SELECT 
    product_category_name,
    order_id,
    order_purchase_timestamp,
    order_delivered_customer_date,
    delivery_time_days,
    -- Simple average of all deliveries in this category
    AVG(delivery_time_days) OVER (
        PARTITION BY product_category_name
    ) AS category_avg_delivery_days,
    -- Rolling average of last 10 deliveries in this category
    AVG(delivery_time_days) OVER (
        PARTITION BY product_category_name 
        ORDER BY order_purchase_timestamp
        ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_10_deliveries,
    -- Rolling average of all previous deliveries including current
    AVG(delivery_time_days) OVER (
        PARTITION BY product_category_name 
        ORDER BY order_purchase_timestamp
        ROWS UNBOUNDED PRECEDING
    ) AS rolling_avg_all_previous,
    -- Count of orders in this category
    COUNT(*) OVER (
        PARTITION BY product_category_name
    ) AS category_order_count,
    -- Percentile rank of this delivery time within category
    PERCENT_RANK() OVER (
        PARTITION BY product_category_name 
        ORDER BY delivery_time_days
    ) AS delivery_time_percentile
FROM 
    CategoryDeliveryBase
GO

-- Test the view
SELECT TOP 100 * 
FROM dbo.vw_category_delivery_analysis
ORDER BY product_category_name, order_purchase_timestamp
GO
