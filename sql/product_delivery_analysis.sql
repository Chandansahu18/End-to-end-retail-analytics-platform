-- Product late delivery rate 
-- Sources: marts.fact_order_item, marts.fact_orders

WITH category_delivery AS (
    SELECT
        foi.category_english,
        COUNT(DISTINCT fo.order_id)                             AS total_orders,
        COUNT(DISTINCT fo.order_id)
            FILTER (WHERE fo.is_late_delivery = TRUE)           AS late_orders,
        ROUND(
            COUNT(DISTINCT fo.order_id)
                FILTER (WHERE fo.is_late_delivery = TRUE)
            / NULLIF(COUNT(DISTINCT fo.order_id), 0) * 100, 1
        )                                                       AS late_delivery_rate_pct,
        AVG(fo.delivery_delay_days)
            FILTER (WHERE fo.is_late_delivery = TRUE)           AS avg_delay_days_when_late,
        AVG(foi.product_weight_g)                               AS avg_product_weight_g,
        SUM(foi.price)                                          AS total_revenue
    FROM marts.fact_order_item foi
    JOIN marts.fact_orders fo
        ON foi.order_id = fo.order_id
    WHERE foi.category_english IS NOT NULL
    GROUP BY foi.category_english
    HAVING COUNT(DISTINCT fo.order_id) >= 50 
),

-- Rank by late delivery rate for conditional formatting threshold
ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY late_delivery_rate_pct DESC)  AS late_rate_rank,
        CASE
            WHEN late_delivery_rate_pct > 20 THEN 'Critical'
            WHEN late_delivery_rate_pct > 10 THEN 'Elevated'
            ELSE 'Normal'
        END AS delivery_risk_tier
    FROM category_delivery
)

SELECT
    late_rate_rank,
    category_english,
    total_orders,
    late_orders,
    late_delivery_rate_pct,
    ROUND(avg_delay_days_when_late, 1) AS avg_delay_days,
    ROUND(avg_product_weight_g, 0)     AS avg_weight_g,
    ROUND(total_revenue, 2)            AS total_revenue_brl,
    delivery_risk_tier
FROM ranked
ORDER BY late_rate_rank
LIMIT 20;