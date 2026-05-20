with source as (
    select * from {{ source('raw', 'orders') }}
),

cleaned as (
    select
        order_id,
        customer_id,
        order_status,

        -- Cast string timestamps to proper TIMESTAMP type
        cast(order_purchase_timestamp as timestamp)    as order_purchase_timestamp,
        cast(order_approved_at as timestamp)           as order_approved_at,
        cast(order_delivered_carrier_date as timestamp) as order_delivered_carrier_date,
        cast(order_delivered_customer_date as timestamp) as order_delivered_customer_date,
        cast(order_estimated_delivery_date as timestamp) as order_estimated_delivery_date,

        -- Derived columns useful downstream
        cast(order_delivered_customer_date as date)
            - cast(order_estimated_delivery_date as date) as delivery_delay_days,

        case
            when cast(order_delivered_customer_date as date)
                 > cast(order_estimated_delivery_date as date)
            then true
            else false
        end as is_late_delivery

    from source
    -- Keep only orders that reached the customer - exclude noise statuses
    where order_status not in ('canceled', 'unavailable')
)

select * from cleaned