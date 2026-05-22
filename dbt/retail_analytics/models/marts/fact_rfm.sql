WITH customer_orders AS (
    SELECT
        customer_unique_id,
        MAX(order_date)                 AS last_order_date,
        COUNT(DISTINCT order_id)        AS frequency,
        SUM(total_order_value)          AS monetary
    FROM {{ ref('fact_orders') }}
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        last_order_date,
        frequency,
        ROUND(monetary, 2)              AS monetary,
        DATEDIFF(
            'day',
            last_order_date,
            DATE '2018-10-01'
        )                               AS recency_days,
        NTILE(5) OVER (
            ORDER BY DATEDIFF('day', last_order_date, DATE '2018-10-01') ASC
        )                               AS r_score,
        NTILE(5) OVER (
            ORDER BY frequency DESC
        )                               AS f_score,
        NTILE(5) OVER (
            ORDER BY monetary DESC
        )                               AS m_score
    FROM customer_orders
)

SELECT
    customer_unique_id,
    last_order_date,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(
        CAST(r_score AS VARCHAR),
        CAST(f_score AS VARCHAR),
        CAST(m_score AS VARCHAR)
    )                                   AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4  THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3  THEN 'Loyal'
        WHEN r_score >= 3 AND f_score >= 1  THEN 'Potential'
        WHEN r_score <= 2 AND f_score >= 2  THEN 'At Risk'
        ELSE                                     'Lost'
    END                                 AS segment
FROM rfm_scores