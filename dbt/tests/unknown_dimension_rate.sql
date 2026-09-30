{{ config(severity='warn') }}

select
    count(*) filter (
        where customer_key = -1 or product_key = -1 or seller_key = -1
    ) as unknown_rows,
    count(*) as total_rows
from {{ ref('fact_order_items') }}
having
    count(*) filter (
        where customer_key = -1 or product_key = -1 or seller_key = -1
    )::numeric / nullif(count(*), 0) > 0.01
