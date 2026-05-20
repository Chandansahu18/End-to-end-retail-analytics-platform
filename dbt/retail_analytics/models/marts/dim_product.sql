with products as (
    select * from {{ ref('stg_products') }}
),

order_items as (
    select
        product_id,
        count(distinct order_id) as times_ordered,
        avg(price)               as avg_price

    from {{ ref('stg_order_items') }}
    group by product_id
),

final as (
    select
        p.product_id            as product_key,
        p.product_category_name_en as category_english,
        p.product_category_name_pt as category_portuguese,
        p.product_photos_qty,
        p.product_weight_g,
        coalesce(oi.times_ordered, 0) as times_ordered,
        coalesce(oi.avg_price, 0)     as avg_price

    from products p
    left join order_items oi on p.product_id = oi.product_id
)

select * from final