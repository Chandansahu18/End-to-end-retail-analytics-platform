-- Category revenue, category mix, month-over-month trends, and state revenue
-- Sources: marts.fact_order_item, marts.fact_order, marts.dim_date


WITH

-- Item-level revenue joined to order and date context
order_items_enriched AS (
    SELECT
        fo.order_id,
        fo.order_date,
        fo.customer_state,
        fo.review_score,
        fo.is_late_delivery,

        d.month_start,
        d.year,
        d.month_num,

        foi.order_item_id,
        foi.product_id,
        foi.category_english,
        foi.price,
        foi.freight_value,
        foi.item_total_value

    FROM marts.fact_order_item foi

    INNER JOIN marts.fact_orders fo
        ON foi.order_id = fo.order_id

    INNER JOIN marts.dim_date d
        ON fo.order_date = d.date_day

    WHERE fo.order_status = 'delivered'
      AND fo.total_order_value > 0
      AND foi.category_english IS NOT NULL
),

-- Product category revenue ranking
category_revenue AS (
    SELECT
        category_english,

        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(order_item_id) AS total_items,

        ROUND(SUM(item_total_value), 2) AS total_revenue,
        ROUND(AVG(price), 2) AS avg_item_price,
        ROUND(
            SUM(item_total_value)
            / NULLIF(COUNT(DISTINCT order_id), 0),
            2
        ) AS revenue_per_order,

        ROUND(AVG(review_score), 2) AS avg_review_score,

        ROUND(
            SUM(CASE WHEN is_late_delivery THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0),
            2
        ) AS late_delivery_pct,

        RANK() OVER (
            ORDER BY SUM(item_total_value) DESC
        ) AS revenue_rank

    FROM order_items_enriched
    GROUP BY category_english
),

-- Monthly revenue by product category
category_monthly AS (
    SELECT
        month_start,
        year,
        month_num,
        category_english,

        ROUND(SUM(item_total_value), 2) AS monthly_revenue,
        COUNT(DISTINCT order_id) AS monthly_orders,
        COUNT(order_item_id) AS monthly_items

    FROM order_items_enriched
    GROUP BY
        month_start,
        year,
        month_num,
        category_english
),

-- Month-over-month category revenue growth
category_with_lag AS (
    SELECT
        month_start,
        category_english,
        monthly_revenue,
        monthly_orders,
        monthly_items,

        LAG(monthly_revenue) OVER (
            PARTITION BY category_english
            ORDER BY month_start
        ) AS prev_month_revenue,

        ROUND(
            (
                monthly_revenue
                - LAG(monthly_revenue) OVER (
                    PARTITION BY category_english
                    ORDER BY month_start
                )
            ) * 100.0
            / NULLIF(
                LAG(monthly_revenue) OVER (
                    PARTITION BY category_english
                    ORDER BY month_start
                ),
                0
            ),
            2
        ) AS mom_growth_pct

    FROM category_monthly
),

-- Category share within each month
category_share AS (
    SELECT
        month_start,
        category_english,
        monthly_revenue,

        ROUND(
            monthly_revenue * 100.0
            / NULLIF(SUM(monthly_revenue) OVER (PARTITION BY month_start), 0),
            2
        ) AS revenue_share_pct

    FROM category_monthly
),

-- Customer state revenue ranking
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

        RANK() OVER (
            ORDER BY SUM(total_order_value) DESC
        ) AS revenue_rank

    FROM marts.fact_orders

    WHERE order_status = 'delivered'
      AND total_order_value > 0
      AND customer_state IS NOT NULL

    GROUP BY customer_state
)

-- 1. Product category revenue ranking
SELECT
    revenue_rank,
    category_english,
    total_orders,
    total_items,
    total_revenue,
    avg_item_price,
    revenue_per_order,
    avg_review_score,
    late_delivery_pct
FROM category_revenue
ORDER BY revenue_rank;

-- 2. MoM revenue trend for top 5 categories
-- SELECT
--     cwl.month_start,
--     cwl.category_english,
--     cwl.monthly_revenue,
--     cs.revenue_share_pct,
--     cwl.prev_month_revenue,
--     cwl.mom_growth_pct
-- FROM category_with_lag cwl
-- INNER JOIN category_share cs
--     ON cwl.month_start = cs.month_start
--     AND cwl.category_english = cs.category_english
-- INNER JOIN category_revenue cr
--     ON cwl.category_english = cr.category_english
-- WHERE cr.revenue_rank <= 5
-- ORDER BY cwl.month_start, cr.revenue_rank;

-- 3. State revenue ranking
-- SELECT
--     customer_state,
--     total_orders,
--     total_revenue,
--     avg_order_value,
--     late_delivery_pct,
--     revenue_rank
-- FROM state_revenue
-- ORDER BY revenue_rank;