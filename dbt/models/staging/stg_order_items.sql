with ranked as (
    select
        *,
        row_number() over (
            partition by order_id, order_item_id
            order by source_updated_at desc nulls last, loaded_at desc
        ) as row_number
    from {{ source('raw', 'order_items') }}
)
select
    trim(order_id) as order_id,
    nullif(order_item_id, '')::integer as order_item_id,
    trim(product_id) as product_id,
    trim(seller_id) as seller_id,
    nullif(shipping_limit_date, '')::timestamp as shipping_limit_date,
    nullif(price, '')::numeric(12, 2) as price,
    nullif(freight_value, '')::numeric(12, 2) as freight_value,
    coalesce(source_updated_at, loaded_at) as record_updated_at
from ranked
where row_number = 1
