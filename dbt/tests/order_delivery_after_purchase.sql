select order_id, order_purchase_timestamp, order_delivered_customer_date
from {{ ref('fact_order_lifecycle') }}
where order_delivered_customer_date < order_purchase_timestamp
