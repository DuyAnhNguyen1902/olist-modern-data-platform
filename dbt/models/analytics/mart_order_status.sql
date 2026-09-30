select
    order_status,
    count(*)::bigint as order_count,
    sum(payment_value)::numeric(16, 2) as revenue,
    avg(payment_value)::numeric(16, 2) as average_order_value,
    (
        count(*)::numeric / nullif(sum(count(*)) over (), 0)
    )::numeric(8, 4) as order_share
from {{ ref('fact_order_lifecycle') }}
group by order_status
