
-- View → Add to Cart → Transaction
-- Source: marts.fact_events

WITH
-- Stage counts from daily summary fact table
funnel_totals AS (
    SELECT
        SUM(unique_visitors) AS total_unique_visitors,
        SUM(total_views) AS total_views,
        SUM(total_addtocarts) AS total_addtocarts,
        SUM(total_transactions) AS total_transactions
    FROM marts.fact_events
),

-- Build funnel stages with drop-off calculations
funnel_stages AS (
    SELECT 1 AS stage_order,
        'View' AS stage_name,
        total_views AS stage_event_count,
        total_views AS top_of_funnel,
        100.0 AS pct_of_top,
        NULL AS drop_off_pct
    FROM funnel_totals

    UNION ALL
    SELECT 2,
        'Add to Cart',
        total_addtocarts,
        total_views,
        ROUND(total_addtocarts * 100.0 / NULLIF(total_views, 0), 2),
        ROUND((total_views - total_addtocarts) * 100.0
              / NULLIF(total_views, 0), 2)
    FROM funnel_totals

    UNION ALL

    SELECT 3,
        'Transaction',
        total_transactions,
        total_views,
        ROUND(total_transactions * 100.0 / NULLIF(total_views, 0), 2),
        ROUND((total_addtocarts - total_transactions) * 100.0
              / NULLIF(total_addtocarts, 0), 2)
    FROM funnel_totals
),

-- Daily funnel trend - how conversion rate changes over time
daily_trend AS (
    SELECT
        event_date,
        unique_visitors,
        total_views,
        total_addtocarts,
        total_transactions,
        view_to_cart_rate,
        cart_to_purchase_rate,
        overall_conversion_rate,
        ROUND(AVG(overall_conversion_rate) OVER (ORDER BY event_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),3) AS rolling_7d_conversion
    FROM marts.fact_events
    ORDER BY event_date
)

-- Overall funnel
SELECT
    stage_order,
    stage_name,
    stage_event_count,
    pct_of_top AS pct_of_total_views,
    drop_off_pct AS drop_off_from_previous_stage
FROM funnel_stages
ORDER BY stage_order;


-- Daily trend:
-- SELECT * FROM daily_trend ORDER BY event_date;