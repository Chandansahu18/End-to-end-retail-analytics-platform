
-- Core business metrics at overall and monthly level
-- Source: marts.fact_orders

WITH

-- Base orders: keeps only valid revenue-generating orders
base_orders AS (
    SELECT
        order_id,
        customer_unique_id,
        order_date,
        order_year,
        order_month,
        total_order_value,
        is_late_delivery,
        review_score
    FROM marts.fact_orders
    WHERE order_status = 'delivered'
    AND total_order_value > 0
),

-- Overall KPI summary
overall_kpis AS (
    SELECT
        'Overall' AS time_period,

        COUNT(DISTINCT order_id) AS total_orders,

        COUNT(DISTINCT customer_unique_id) AS unique_customers,

        ROUND(SUM(total_order_value), 2) AS total_revenue,

        ROUND(AVG(total_order_value), 2) AS avg_order_value,

        ROUND(
            SUM(total_order_value)
            / NULLIF(COUNT(DISTINCT customer_unique_id), 0),
            2
        ) AS revenue_per_customer,

        ROUND(
            COUNT(DISTINCT order_id) * 1.0
            / NULLIF(COUNT(DISTINCT customer_unique_id), 0),
            2
        ) AS avg_order_frequency,

        ROUND(AVG(review_score), 2) AS avg_review_score,

        ROUND(
            SUM(CASE WHEN is_late_delivery THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0),
            2
        ) AS late_delivery_pct,

        -- Not applicable for overall row
        CAST(NULL AS DOUBLE) AS prev_month_revenue,
        CAST(NULL AS DOUBLE) AS revenue_growth_pct

    FROM base_orders
),

-- Monthly KPI aggregation
-- One row per calendar month
monthly_kpis AS (
    SELECT

        -- Format year-month reporting period
        CAST(order_year AS VARCHAR)
            || '-'
            || LPAD(CAST(order_month AS VARCHAR), 2, '0') AS time_period,

        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_unique_id) AS unique_customers,

        ROUND(SUM(total_order_value), 2) AS total_revenue,

        ROUND(AVG(total_order_value), 2) AS avg_order_value,

        ROUND(
            SUM(total_order_value)
            / NULLIF(COUNT(DISTINCT customer_unique_id), 0),
            2
        ) AS revenue_per_customer,

        ROUND(
            COUNT(DISTINCT order_id) * 1.0
            / NULLIF(COUNT(DISTINCT customer_unique_id), 0),
            2
        ) AS avg_order_frequency,

        ROUND(AVG(review_score), 2) AS avg_review_score,

        ROUND(
            SUM(CASE WHEN is_late_delivery THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0),
            2
        ) AS late_delivery_pct

    FROM base_orders
    GROUP BY order_year, order_month
),

-- Add month-over-month revenue comparison
-- Previous month revenue tracking
monthly_with_growth AS (
    SELECT
        time_period,
        total_orders,
        unique_customers,
        total_revenue,
        avg_order_value,
        revenue_per_customer,
        avg_order_frequency,
        avg_review_score,
        late_delivery_pct,

        -- Previous month's revenue
        LAG(total_revenue)
            OVER (ORDER BY time_period) AS prev_month_revenue,

        -- Month-over-month revenue growth percentage
        ROUND(
            (
                total_revenue
                - LAG(total_revenue)
                    OVER (ORDER BY time_period)
            ) * 100.0
            / NULLIF(
                LAG(total_revenue)
                    OVER (ORDER BY time_period),
                0
            ),
            2
        ) AS revenue_growth_pct

    FROM monthly_kpis
),

-- Combine overall summary: row with monthly KPI rows
combined AS (

    SELECT
        time_period,
        total_orders,
        unique_customers,
        total_revenue,
        avg_order_value,
        revenue_per_customer,
        avg_order_frequency,
        avg_review_score,
        late_delivery_pct,
        prev_month_revenue,
        revenue_growth_pct
    FROM overall_kpis

    UNION ALL

    SELECT
        time_period,
        total_orders,
        unique_customers,
        total_revenue,
        avg_order_value,
        revenue_per_customer,
        avg_order_frequency,
        avg_review_score,
        late_delivery_pct,
        prev_month_revenue,
        revenue_growth_pct
    FROM monthly_with_growth
)

-- Overall summary: first, followed by monthly trend rows
SELECT *
FROM combined

ORDER BY
    CASE
        WHEN time_period = 'Overall' THEN 0
        ELSE 1
    END,
    time_period;