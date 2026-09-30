select
    d.date_key,
    d.full_date,
    d.day_name,
    d.month_number,
    d.month_name,
    d.quarter_number,
    d.year_number,
    d.is_weekend,
    count(*)::bigint as order_count,
    sum(f.payment_value)::numeric(16, 2) as revenue,
    avg(f.payment_value)::numeric(16, 2) as average_order_value,
    sum(f.merchandise_value)::numeric(16, 2) as merchandise_value,
    sum(f.freight_value)::numeric(16, 2) as freight_value,
    count(*) filter (where f.is_delivered_late)::bigint as late_order_count,
    count(*) filter (where f.is_cancelled)::bigint as cancelled_order_count
from {{ ref('fact_order_lifecycle') }} f
join {{ ref('dim_date') }} d on f.purchase_date_key = d.date_key
group by
    d.date_key,
    d.full_date,
    d.day_name,
    d.month_number,
    d.month_name,
    d.quarter_number,
    d.year_number,
    d.is_weekend
