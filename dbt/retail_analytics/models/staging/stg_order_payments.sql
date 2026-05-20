with source as (
    select * from {{ source('raw', 'order_payments') }}
),

cleaned as (
    select
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value

    from source
    -- Exclude unknown payment types
    where payment_type != 'not_defined'
)

select * from cleaned