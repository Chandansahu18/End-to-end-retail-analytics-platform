with enriched as (
    select * from {{ ref('int_orders_enriched') }}
),

reviews as (
    select
        order_id,
        avg(review_score) as review_score,
        any_value(review_comment_message) as review_comment_message
    from {{ ref('stg_order_reviews') }}
    group by order_id
),

sellers as (
    select
        order_id,
        seller_id

    from {{ ref('stg_order_items') }}
    -- One seller per order for simplicity — take the first
    qualify row_number() over (partition by order_id order by order_id) = 1
),

final as (
    select
        e.order_id,
        e.customer_unique_id,
        s.seller_id,
        cast(e.order_purchase_timestamp as date)    as order_date,
        extract(year from e.order_purchase_timestamp)::int  as order_year,
        extract(month from e.order_purchase_timestamp)::int as order_month,
        e.order_status,
        e.customer_state,
        e.item_count,
        e.total_product_value,
        e.total_freight_value,
        e.total_order_value,
        e.primary_payment_type,
        e.max_installments,
        e.is_split_payment,
        e.delivery_delay_days,
        e.is_late_delivery,
        r.review_score,
        case
            when r.review_score >= 4 then 'positive'
            when r.review_score = 3  then 'neutral'
            else 'negative'
        end as review_sentiment

    from enriched e
    left join reviews r  on e.order_id = r.order_id
    left join sellers s  on e.order_id = s.order_id
)

select * from final