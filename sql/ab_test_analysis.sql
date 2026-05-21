
-- Simulated experiment: split RetailRocket visitors into two groups
-- by hashing visitor_id. Group A = control, Group B = treatment.
-- Test whether conversion rates differ significantly.
-- Source: staging.stg_events (visitor-level events)

WITH
-- Step 1: Assign each visitor to a test group by hashing visitor_id
visitor_groups AS (
    SELECT
        visitor_id,
        CASE WHEN visitor_id % 2 = 0 THEN 'A' ELSE 'B' END  AS test_group
    FROM (
        SELECT DISTINCT visitor_id
        FROM staging.stg_events
    ) visitors
),

-- Step 2: Calculate conversion per visitor
visitor_conversions AS (
    SELECT
        e.visitor_id,
        vg.test_group,
        MAX(CASE WHEN e.event_type = 'transaction' THEN 1 ELSE 0 END) AS converted
    FROM staging.stg_events e
    INNER JOIN visitor_groups vg
        ON e.visitor_id = vg.visitor_id
    GROUP BY e.visitor_id, vg.test_group
),

-- Step 3: Aggregate per group
group_stats AS (
    SELECT
        test_group,
        COUNT(*) AS sample_size,
        SUM(converted) AS conversions,
        ROUND(AVG(converted) * 100,3) AS conversion_rate_pct,
        AVG(converted) AS conversion_rate   
    FROM visitor_conversions
    GROUP BY test_group
),

-- Step 4: Prepare values for z-score calculation
test_values AS (
    SELECT
        MAX(CASE WHEN test_group = 'A' THEN conversion_rate END) AS p1,
        MAX(CASE WHEN test_group = 'B' THEN conversion_rate END) AS p2,
        MAX(CASE WHEN test_group = 'A' THEN sample_size END) AS n1,
        MAX(CASE WHEN test_group = 'B' THEN sample_size END) AS n2,
        MAX(CASE WHEN test_group = 'A' THEN conversions END) AS conv1,
        MAX(CASE WHEN test_group = 'B' THEN conversions END) AS conv2
    FROM group_stats
),

-- Step 5: Calculate pooled proportion and z-score
z_calculation AS (
    SELECT
        p1, p2, n1, n2,
        (conv1 + conv2) * 1.0 / (n1 + n2) AS p_pool,
        ABS(p1 - p2) AS rate_difference
    FROM test_values
),

z_score_final AS (
    SELECT
        p1 AS group_a_rate,
        p2 AS group_b_rate,
        n1 AS group_a_size,
        n2 AS group_b_size,
        ROUND((p1 - p2) * 100,3) AS rate_difference_pct,
        p_pool,
        ROUND(
            (p1 - p2) /
            NULLIF(
                SQRT(p_pool * (1 - p_pool) * (1.0/n1 + 1.0/n2))
            , 0)
        , 3) AS z_score
    FROM z_calculation
),

-- Step 6: Interpret result
interpretation AS (
    SELECT
        *,
        ABS(z_score) AS abs_z_score,
        CASE
            WHEN ABS(z_score) >= 2.576 THEN 'Statistically significant at 99% confidence'
            WHEN ABS(z_score) >= 1.960 THEN 'Statistically significant at 95% confidence'
            WHEN ABS(z_score) >= 1.645 THEN 'Statistically significant at 90% confidence'
            ELSE 'Not statistically significant — could be random variation'
        END AS significance_conclusion,
        CASE
            WHEN z_score > 0 THEN 'Group A converts better'
            WHEN z_score < 0 THEN 'Group B converts better'
            ELSE 'No difference'
        END AS winning_group
    FROM z_score_final
)

-- Final output
SELECT
    ROUND(group_a_rate * 100,3) AS group_a_conversion_pct,
    ROUND(group_b_rate * 100,3) AS group_b_conversion_pct,
    group_a_size,
    group_b_size,
    rate_difference_pct AS difference_pct_points,
    z_score,
    abs_z_score,
    winning_group,
    significance_conclusion
FROM interpretation;