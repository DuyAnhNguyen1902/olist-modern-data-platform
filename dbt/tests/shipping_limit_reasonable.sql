{{ config(severity='warn') }}

select i.order_id, i.order_item_id, i.shipping_limit_date, o.order_purchase_timestamp
from {{ ref('stg_order_items') }} i
join {{ ref('stg_orders') }} o on i.order_id = o.order_id
where i.shipping_limit_date > o.order_purchase_timestamp + interval '365 days'
