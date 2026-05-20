with marketing as (
    select * from {{ ref('stg_marketing') }}
)

select
    campaign_month,
    channel,
    spend,
    impressions,
    clicks,
    conversions,
    revenue_attributed,
    roas,
    cpa,
    ctr,
    -- Channel performance tier
    case
        when roas >= 4.0 then 'high_performance'
        when roas >= 2.5 then 'mid_performance'
        else 'low_performance'
    end as performance_tier

from marketing