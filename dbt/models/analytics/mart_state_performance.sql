select
    coalesce(c.state, 'Unknown') as customer_state,
    count(*)::bigint as order_count,
    sum(f.payment_value)::numeric(16, 2) as revenue,
    avg(f.payment_value)::numeric(16, 2) as average_order_value,
    count(*) filter (where f.is_delivered_late)::bigint as late_order_count,
    (
        count(*) filter (where f.is_delivered_late)::numeric
        / nullif(count(*) filter (where f.order_delivered_customer_date is not null), 0)
    )::numeric(8, 4) as late_delivery_rate
from {{ ref('fact_order_lifecycle') }} f
join {{ ref('dim_customer') }} c on f.customer_key = c.customer_key
group by coalesce(c.state, 'Unknown')
