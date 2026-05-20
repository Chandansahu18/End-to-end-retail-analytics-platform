with source as (
    select * from {{ source('raw', 'order_items') }}
),

cleaned as (
    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        cast(shipping_limit_date as timestamp) as shipping_limit_date,
        price,
        freight_value,

        -- Total item value including freight
        price + freight_value as item_total_value

    from source
)

select * from cleaned