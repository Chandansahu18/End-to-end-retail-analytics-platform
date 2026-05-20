with source as (
    select * from {{ source('raw', 'marketing') }}
),

cleaned as (
    select
        cast(campaign_month as date) as campaign_month,
        channel,
        spend,
        impressions,
        clicks,
        conversions,
        revenue_attributed,
        roas,
        cpa,
        ctr

    from source
)

select * from cleaned