WITH order_items AS (
    SELECT
        oi.order_id || '-' || CAST(oi.order_item_id AS VARCHAR) AS order_item_key,
        oi.order_id,
        oi.order_item_id,
        oi.product_id,
        oi.seller_id,
        oi.price,
        oi.freight_value,
        oi.item_total_value
    FROM {{ ref('stg_order_items') }} oi
),

product_lookup AS (
    SELECT
        product_key,
        category_english,
        category_portuguese,
        avg_price,
        product_weight_g,
        product_photos_qty
    FROM {{ ref('dim_product') }}
)

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    oi.item_total_value,
    -- Enriched from dim_product
    p.category_english,
    p.category_portuguese,
    p.product_weight_g,
    p.product_photos_qty
FROM order_items oi
LEFT JOIN product_lookup p
    ON oi.product_id = p.product_key