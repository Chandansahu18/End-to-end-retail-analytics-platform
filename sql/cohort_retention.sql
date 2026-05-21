
-- 12-month retention window
-- Source: marts.fact_orders + marts.dim_customer

WITH

-- Step 1: Get all orders with purchase month
orders AS (
    SELECT
        customer_unique_id,
        DATE_TRUNC('month', order_date)::DATE AS order_month
    FROM marts.fact_orders
    WHERE customer_unique_id IS NOT NULL
),

-- Step 2: Find each customer's first purchase month - their cohort
customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM orders
    GROUP BY customer_unique_id
),

-- Step 3: Join back to get every order month per customer,
-- calculate how many months after cohort each order happened
cohort_activity AS (
    SELECT
        c.cohort_month,
        o.customer_unique_id,
        -- Months since first purchase (0 = acquisition month)
        DATEDIFF('month', c.cohort_month, o.order_month) AS months_since_first
    FROM orders o
    INNER JOIN customer_cohorts c
        ON o.customer_unique_id = c.customer_unique_id
),

-- Step 4: Count cohort size and active customers per period
cohort_counts AS (
    SELECT
        cohort_month,
        months_since_first,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, months_since_first
),

-- Step 5: Get cohort size (month 0 = acquisition count)
cohort_sizes AS (
    SELECT
        cohort_month,
        active_customers AS cohort_size
    FROM cohort_counts
    WHERE months_since_first = 0
),

-- Step 6: Calculate retention percentage
retention AS (
    SELECT
        cc.cohort_month,
        cc.months_since_first,
        cc.active_customers,
        cs.cohort_size,
        ROUND(cc.active_customers * 100.0 / cs.cohort_size, 1) AS retention_pct
    FROM cohort_counts cc
    INNER JOIN cohort_sizes cs
        ON cc.cohort_month = cs.cohort_month
    WHERE cc.months_since_first <= 11   -- 12-month window (0 through 11)
)

-- Final: Pivot to matrix format - one column per month offset
SELECT
    cohort_month,
    cohort_size,
    MAX(CASE WHEN months_since_first = 0  THEN retention_pct END)  AS "Month 0",
    MAX(CASE WHEN months_since_first = 1  THEN retention_pct END)  AS "Month 1",
    MAX(CASE WHEN months_since_first = 2  THEN retention_pct END)  AS "Month 2",
    MAX(CASE WHEN months_since_first = 3  THEN retention_pct END)  AS "Month 3",
    MAX(CASE WHEN months_since_first = 4  THEN retention_pct END)  AS "Month 4",
    MAX(CASE WHEN months_since_first = 5  THEN retention_pct END)  AS "Month 5",
    MAX(CASE WHEN months_since_first = 6  THEN retention_pct END)  AS "Month 6",
    MAX(CASE WHEN months_since_first = 7  THEN retention_pct END)  AS "Month 7",
    MAX(CASE WHEN months_since_first = 8  THEN retention_pct END)  AS "Month 8",
    MAX(CASE WHEN months_since_first = 9  THEN retention_pct END)  AS "Month 9",
    MAX(CASE WHEN months_since_first = 10 THEN retention_pct END)  AS "Month 10",
    MAX(CASE WHEN months_since_first = 11 THEN retention_pct END)  AS "Month 11"
FROM retention
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;