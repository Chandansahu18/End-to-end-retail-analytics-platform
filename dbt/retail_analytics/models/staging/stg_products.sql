with source as (
    select * from {{ source('raw', 'products') }}
),

translation as (
    select * from {{ source('raw', 'product_category_translation') }}
),

cleaned as (
    select
        p.product_id,
        coalesce(p.product_category_name, 'uncategorized') as product_category_name_pt,
        coalesce(t.product_category_name_english, 'uncategorized') as product_category_name_en,
        -- Fix source typos in column names
        p.product_name_lenght       as product_name_length,
        p.product_description_lenght as product_description_length,
        p.product_photos_qty,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm

    from source p
    left join translation t
        on p.product_category_name = t.product_category_name
)

select * from cleaned