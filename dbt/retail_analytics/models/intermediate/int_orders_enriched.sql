-- Join orders with items, payments, customers, products
with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select
        order_id,
        count(order_item_id)        as item_count,
        sum(price)                  as total_product_value,
        sum(freight_value)          as total_freight_value,
        sum(item_total_value)       as total_order_value

    from {{ ref('stg_order_items') }}
    group by order_id
),

payments as (
    select * from {{ ref('int_order_payments') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

enriched as (
    select
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        c.customer_state,
        c.customer_city,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        o.delivery_delay_days,
        o.is_late_delivery,
        
        coalesce(i.item_count, 0) as item_count,
        coalesce(i.total_product_value, 0) as total_product_value,
        coalesce(i.total_freight_value, 0) as total_freight_value,
        coalesce(i.total_order_value, 0) as total_order_value,

        p.total_payment_value,
        p.primary_payment_type,
        p.max_installments,
        p.is_split_payment

    from orders o
    left join customers c    on o.customer_id = c.customer_id
    left join order_items i  on o.order_id = i.order_id
    left join payments p     on o.order_id = p.order_id
)

select * from enriched