-- Custom test: no order should have a negative total value

select
    order_id,
    total_order_value

from {{ ref('fact_orders') }}

where total_order_value < 0