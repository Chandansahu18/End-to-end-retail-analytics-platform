with source as (
    select * from {{ source('raw', 'customers') }}
),

cleaned as (
    select
        customer_id,
        customer_unique_id,
        -- Cast zip to VARCHAR to preserve leading zeros
        lpad(cast(customer_zip_code_prefix as varchar), 5, '0') as customer_zip_code_prefix,
        -- Normalise city name encoding
        lower(trim(customer_city)) as customer_city,
        upper(trim(customer_state)) as customer_state

    from source
)

select * from cleaned