
-- Customer segmentation using Recency, Frequency, and Monetary value
-- Source: marts.fact_orders
-- Scope: delivered orders with valid revenue

WITH 
-- Base RFM metrics calculated at customer level
rfm_raw AS (
    SELECT
        customer_unique_id,

        DATEDIFF(
            'day',
            MAX(order_date),
            (SELECT MAX(order_date) FROM marts.fact_orders)
        ) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,
        ROUND(SUM(total_order_value), 2) AS monetary

    FROM marts.fact_orders
    WHERE order_status = 'delivered'
      AND total_order_value > 0
      AND customer_unique_id IS NOT NULL
    GROUP BY customer_unique_id
),

-- Assign RFM scores using NTILE(5)
-- Score 5 shows strongest customer behavior
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score

    FROM rfm_raw
),

-- Segment customers using RFM score combinations
rfm_segments AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,

        CAST(r_score AS VARCHAR)
            || CAST(f_score AS VARCHAR)
            || CAST(m_score AS VARCHAR) AS rfm_score,

        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Champions'

            WHEN r_score >= 3 AND f_score >= 4
                THEN 'Loyal Customers'

            WHEN r_score >= 4 AND f_score = 1
                THEN 'New Customers'

            WHEN r_score >= 3 AND f_score BETWEEN 2 AND 3 AND m_score >= 3
                THEN 'Potential Loyalists'

            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4
                THEN 'Cannot Lose Them'

            WHEN r_score <= 2 AND f_score >= 3
                THEN 'At Risk'

            WHEN r_score <= 2 AND f_score <= 2
                THEN 'Lost'

            ELSE 'Needs Attention'
        END AS customer_segment

    FROM rfm_scores
),

-- Aggregate segment-level business metrics
segment_summary AS (
    SELECT
        customer_segment,
        COUNT(*) AS customer_count,

        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_pct,

        ROUND(AVG(recency_days), 1) AS avg_recency_days,
        ROUND(AVG(frequency), 2) AS avg_frequency,
        ROUND(AVG(monetary), 2) AS avg_monetary_value,

        ROUND(SUM(monetary), 2) AS total_segment_revenue,
        ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 2) AS revenue_pct

    FROM rfm_segments
    GROUP BY customer_segment
)

-- Segment-level summary
SELECT
    customer_segment,
    customer_count,
    customer_pct,
    avg_recency_days,
    avg_frequency,
    avg_monetary_value,
    total_segment_revenue,
    revenue_pct
FROM segment_summary
ORDER BY total_segment_revenue DESC;

-- Customer-level output for validation
--SELECT *
--FROM rfm_segments
--ORDER BY monetary DESC;