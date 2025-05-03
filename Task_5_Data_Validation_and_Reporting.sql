-- Task 5: Data Validation and Reporting

USE OlistDB;
GO

-- 1 - Joins fact_order_items with dim_products and uses GROUP BY product_category_name

SELECT 
    COALESCE(dp.product_category_name, 'Unknown') AS product_category,
    COUNT(DISTINCT f.order_id) AS order_count,
    COUNT(f.order_item_id) AS product_count,
    SUM(f.product_price) AS product_sales,
    SUM(f.freight_value) AS shipping_revenue,
    SUM(f.total_price) AS total_sales
FROM 
    dw.fact_order_items f
JOIN 
    dw.dim_products dp ON f.product_key = dp.product_key
GROUP BY 
    COALESCE(dp.product_category_name, 'Unknown')
ORDER BY 
    total_sales DESC;
GO


-- 2 - Joins fact_order_items with dim_sellers and uses AVG(delivery_time_days)

SELECT 
    ds.seller_id,
    ds.seller_state,
    ds.seller_city,
    COUNT(DISTINCT f.order_id) AS order_count,
    AVG(f.delivery_time_days) AS avg_delivery_days,
    MIN(f.delivery_time_days) AS min_delivery_days,
    MAX(f.delivery_time_days) AS max_delivery_days
FROM 
    dw.fact_order_items f
JOIN 
    dw.dim_sellers ds ON f.seller_key = ds.seller_key
WHERE 
    f.delivery_time_days IS NOT NULL
GROUP BY 
    ds.seller_id,
    ds.seller_state,
    ds.seller_city
HAVING 
    COUNT(DISTINCT f.order_id) >= 5  -- Only include sellers with at least 5 orders
ORDER BY 
    avg_delivery_days;
GO


-- 3 - Joins fact_order_items with dim_customers and groups by customer_state

SELECT 
    dc.customer_state,
    COUNT(DISTINCT f.order_id) AS order_count,
    COUNT(DISTINCT f.customer_key) AS customer_count,
    COUNT(DISTINCT f.order_id) * 1.0 / COUNT(DISTINCT f.customer_key) AS orders_per_customer,
    SUM(f.total_price) AS total_sales
FROM 
    dw.fact_order_items f
JOIN 
    dw.dim_customers dc ON f.customer_key = dc.customer_key
GROUP BY 
    dc.customer_state
ORDER BY 
    order_count DESC;
GO