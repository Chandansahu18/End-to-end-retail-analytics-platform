with funnel as (
    select * from {{ ref('int_funnel_events') }}
),

daily_summary as (
    select
        event_date,
        count(distinct visitor_id)                          as unique_visitors,
        sum(view_count)                                     as total_views,
        sum(addtocart_count)                                as total_addtocarts,
        sum(transaction_count)                              as total_transactions,
        -- Conversion rates
        round(
            sum(addtocart_count) * 100.0 / nullif(sum(view_count), 0),
        2) as view_to_cart_rate,
        round(
            sum(transaction_count) * 100.0 / nullif(sum(addtocart_count), 0),
        2) as cart_to_purchase_rate,
        round(
            sum(transaction_count) * 100.0 / nullif(sum(view_count), 0),
        2) as overall_conversion_rate

    from funnel
    group by event_date
)

select * from daily_summary