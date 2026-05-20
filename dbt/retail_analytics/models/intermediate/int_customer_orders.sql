with enriched as (
    select * from {{ ref('int_orders_enriched') }}
),

customer_summary as (
    select
        customer_unique_id,

        any_value(customer_state) as customer_state,
        any_value(customer_city) as customer_city,

        count(distinct order_id) as total_orders,
        sum(total_order_value) as lifetime_value,
        avg(total_order_value) as avg_order_value,
        min(order_purchase_timestamp) as first_order_date,
        max(order_purchase_timestamp) as last_order_date,

        datediff(
            'day',
            min(order_purchase_timestamp),
            max(order_purchase_timestamp)
        ) as customer_lifespan_days,

        case
            when count(distinct order_id) > 1 then true
            else false
        end as is_repeat_customer

    from enriched
    where customer_unique_id is not null
    group by customer_unique_id
)

select * from customer_summary