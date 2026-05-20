-- dim_customer uses customer_unique_id as primary key — NOT customer_id
-- customer_id changes per order. customer_unique_id is the stable person identifier.
with customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

geo as (
    select * from {{ ref('stg_geolocation') }}
),

customers_raw as (
    select
        customer_unique_id,
        any_value(customer_zip_code_prefix) as customer_zip_code_prefix
    from {{ ref('stg_customers') }}
    group by customer_unique_id
),

final as (
    select
        co.customer_unique_id                   as customer_key,
        co.customer_city,
        co.customer_state,
        g.latitude,
        g.longitude,
        co.total_orders,
        co.lifetime_value,
        co.avg_order_value,
        co.first_order_date,
        co.last_order_date,
        co.customer_lifespan_days,
        co.is_repeat_customer,
        -- Customer segment by lifetime value
        case
            when co.lifetime_value >= 1000 then 'high_value'
            when co.lifetime_value >= 300  then 'mid_value'
            else 'low_value'
        end as customer_segment

    from customer_orders co
    left join customers_raw cr  on co.customer_unique_id = cr.customer_unique_id
    left join geo g              on cr.customer_zip_code_prefix = g.zip_code_prefix
)

select * from final