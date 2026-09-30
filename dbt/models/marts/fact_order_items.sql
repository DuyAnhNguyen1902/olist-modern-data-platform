{{ config(
    materialized='incremental',
    unique_key=['order_id', 'order_item_id'],
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}

select
    {{ stable_key("i.order_id || '|' || i.order_item_id::text") }} as order_item_key,
    i.order_id,
    i.order_item_id,
    coalesce(c.customer_key, -1) as customer_key,
    coalesce(p.product_key, -1) as product_key,
    coalesce(s.seller_key, -1) as seller_key,
    to_char(o.order_purchase_timestamp, 'YYYYMMDD')::integer as order_date_key,
    to_char(i.shipping_limit_date, 'YYYYMMDD')::integer as shipping_date_key,
    1::integer as quantity,
    i.price as item_price,
    i.freight_value,
    (i.price + i.freight_value)::numeric(12, 2) as total_item_value,
    greatest(i.record_updated_at, o.record_updated_at) as record_updated_at
from {{ ref('stg_order_items') }} i
join {{ ref('stg_orders') }} o on i.order_id = o.order_id
left join {{ ref('dim_customer') }} c on o.customer_id = c.customer_id
left join {{ ref('dim_product') }} p on i.product_id = p.product_id
left join {{ ref('dim_seller') }} s on i.seller_id = s.seller_id
{% if is_incremental() %}
where greatest(i.record_updated_at, o.record_updated_at) > (
    select coalesce(max(record_updated_at), '1970-01-01'::timestamptz) from {{ this }}
)
{% endif %}
