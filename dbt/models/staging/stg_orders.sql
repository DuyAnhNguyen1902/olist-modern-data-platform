with ranked as (
    select
        *,
        row_number() over (
            partition by order_id
            order by source_updated_at desc nulls last, loaded_at desc
        ) as row_number
    from {{ source('raw', 'orders') }}
)
select
    trim(order_id) as order_id,
    trim(customer_id) as customer_id,
    lower(trim(order_status)) as order_status,
    nullif(order_purchase_timestamp, '')::timestamp as order_purchase_timestamp,
    nullif(order_approved_at, '')::timestamp as order_approved_at,
    nullif(order_delivered_carrier_date, '')::timestamp as order_delivered_carrier_date,
    nullif(order_delivered_customer_date, '')::timestamp as order_delivered_customer_date,
    nullif(order_estimated_delivery_date, '')::timestamp as order_estimated_delivery_date,
    coalesce(source_updated_at, loaded_at) as record_updated_at
from ranked
where row_number = 1
