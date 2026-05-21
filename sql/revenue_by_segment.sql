-- Category revenue, state revenue, and month-over-month category trends
-- Sources: marts.fact_orders, staging.stg_order_items, marts.dim_product

WITH

-- Order-item level dataset enriched with product category
orders_with_product AS (
    SELECT
        fo.order_id,
        fo.order_date,
        fo.order_year,
        fo.order_month,
        fo.customer_state,
        fo.total_order_value,
        fo.review_score,
        fo.is_late_delivery,
        oi.product_id,
        oi.price,
        oi.item_total_value
    FROM marts.fact_orders fo
    INNER JOIN staging.stg_order_items oi
        ON fo.order_id = oi.order_id
    WHERE fo.order_status = 'delivered'
      AND fo.total_order_value > 0
),

product_enriched AS (
    SELECT
        owp.*,
        dp.category_english,
        dp.avg_price AS catalog_avg_price
    FROM orders_with_product owp
    LEFT JOIN marts.dim_product dp
        ON owp.product_id = dp.product_key
),

-- Revenue ranking by product category
category_revenue AS (
    SELECT
        category_english,
        COUNT(DISTINCT order_id) AS total_orders,
        ROUND(SUM(item_total_value), 2) AS total_revenue,
        ROUND(AVG(price), 2) AS avg_item_price,
        ROUND(AVG(review_score), 2) AS avg_review_score,
        ROUND(
            SUM(CASE WHEN is_late_delivery THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0),
            2
        ) AS late_delivery_pct,
        RANK() OVER (ORDER BY SUM(item_total_value) DESC) AS revenue_rank
    FROM product_enriched
    GROUP BY category_english
),

-- Monthly revenue by category
category_monthly AS (
    SELECT
        CAST(order_year AS VARCHAR)
            || '-'
            || LPAD(CAST(order_month AS VARCHAR), 2, '0') AS month,
        category_english,
        ROUND(SUM(item_total_value), 2) AS monthly_revenue
    FROM product_enriched
    GROUP BY order_year, order_month, category_english
),

-- Month-over-month category revenue growth
category_with_lag AS (
    SELECT
        month,
        category_english,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            PARTITION BY category_english
            ORDER BY month
        ) AS prev_month_revenue,
        ROUND(
            (
                monthly_revenue
                - LAG(monthly_revenue) OVER (
                    PARTITION BY category_english
                    ORDER BY month
                )
            ) * 100.0
            / NULLIF(
                LAG(monthly_revenue) OVER (
                    PARTITION BY category_english
                    ORDER BY month
                ),
                0
            ),
            2
        ) AS mom_growth_pct
    FROM category_monthly
),

-- Revenue ranking by customer state
state_revenue AS (
    SELECT
        customer_state,
        COUNT(DISTINCT order_id) AS total_orders,
        ROUND(SUM(total_order_value), 2) AS total_revenue,
        ROUND(AVG(total_order_value), 2) AS avg_order_value,
        ROUND(
            SUM(CASE WHEN is_late_delivery THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0),
            2
        ) AS late_delivery_pct,
        RANK() OVER (ORDER BY SUM(total_order_value) DESC) AS revenue_rank
    FROM marts.fact_orders
    WHERE order_status = 'delivered'
      AND total_order_value > 0
      AND customer_state IS NOT NULL
    GROUP BY customer_state
)

-- 1. Category revenue ranking
SELECT *
FROM category_revenue
ORDER BY revenue_rank;

-- 2. MoM category growth
-- SELECT *
-- FROM category_with_lag
-- WHERE category_english IN (
--     SELECT category_english
--     FROM category_revenue
--     WHERE revenue_rank <= 5
-- )
-- ORDER BY category_english, month;

-- 3. State revenue ranking
-- SELECT *
-- FROM state_revenue
-- ORDER BY revenue_rank;