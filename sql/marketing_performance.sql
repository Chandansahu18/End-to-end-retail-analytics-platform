-- Marketing channel performance, efficiency, and monthly ROAS trends
-- Source: marts.fact_marketing

WITH
-- Overall channel-level performance
channel_overall AS (
    SELECT
        channel,
        COUNT(*) AS months_active,
        ROUND(SUM(spend), 2) AS total_spend,
        ROUND(SUM(revenue_attributed), 2) AS total_revenue,
        ROUND(SUM(revenue_attributed) /
              NULLIF(SUM(spend), 0), 2) AS blended_roas,
        ROUND(SUM(spend) /
              NULLIF(SUM(conversions), 0), 2) AS blended_cpa,
        ROUND(AVG(ctr), 3) AS avg_ctr,
        ROUND(AVG(roas), 2) AS avg_monthly_roas,
        ROUND(SUM(impressions), 0) AS total_impressions,
        ROUND(SUM(clicks), 0) AS total_clicks,
        ROUND(SUM(conversions), 0) AS total_conversions,
        RANK() OVER (
            ORDER BY SUM(revenue_attributed) / NULLIF(SUM(spend), 0) DESC
        ) AS efficiency_rank
    FROM marts.fact_marketing
    GROUP BY channel
),

-- Monthly channel performance with MoM ROAS and cumulative spend
monthly_channel AS (
    SELECT
        campaign_month,
        channel,
        spend,
        revenue_attributed,
        roas,
        cpa,
        ctr,
        conversions,
        performance_tier,
        LAG(roas) OVER (
            PARTITION BY channel
            ORDER BY campaign_month
        ) AS prev_month_roas,
        ROUND(roas - LAG(roas) OVER (
            PARTITION BY channel ORDER BY campaign_month
        ), 2) AS roas_change,
        SUM(spend) OVER (
            PARTITION BY channel
            ORDER BY campaign_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_spend,
        RANK() OVER (
            PARTITION BY campaign_month
            ORDER BY roas DESC
        ) AS monthly_roas_rank
    FROM marts.fact_marketing
),

-- Budget share vs revenue share by channel
budget_allocation AS (
    SELECT
        channel,
        total_spend,
        total_revenue,
        blended_roas,
        blended_cpa,
        efficiency_rank,
        ROUND(total_spend * 100.0 /
              SUM(total_spend) OVER (), 1) AS budget_share_pct,
        ROUND(total_revenue * 100.0 /
              SUM(total_revenue) OVER (), 1) AS revenue_share_pct,
        ROUND(
            (total_revenue * 100.0 / SUM(total_revenue) OVER ()) -
            (total_spend * 100.0 / SUM(total_spend) OVER ())
        , 1) AS efficiency_delta
    FROM channel_overall
)

-- Overall channel ranking
SELECT * FROM channel_overall ORDER BY efficiency_rank;

-- Budget allocation efficiency
-- SELECT * FROM budget_allocation ORDER BY efficiency_delta DESC;

-- Monthly trends
-- SELECT * FROM monthly_channel ORDER BY campaign_month, monthly_roas_rank;