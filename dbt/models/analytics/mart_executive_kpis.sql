select
    'all_time'::text as metric_scope,
    count(*)::bigint as total_orders,
    sum(payment_value)::numeric(16, 2) as total_revenue,
    avg(payment_value)::numeric(16, 2) as average_order_value,
    count(*) filter (where order_status = 'delivered')::bigint as delivered_orders,
    count(*) filter (where is_cancelled)::bigint as cancelled_orders,
    (
        count(*) filter (where is_cancelled)::numeric
        / nullif(count(*), 0)
    )::numeric(8, 4) as cancellation_rate,
    (
        count(*) filter (where is_delivered_late)::numeric
        / nullif(count(*) filter (where order_delivered_customer_date is not null), 0)
    )::numeric(8, 4) as late_delivery_rate
from {{ ref('fact_order_lifecycle') }}
