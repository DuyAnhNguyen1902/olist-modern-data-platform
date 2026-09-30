select
    coalesce(p.category_name_english, 'Unknown') as category_name,
    count(distinct f.order_id)::bigint as order_count,
    sum(f.quantity)::bigint as item_count,
    sum(f.item_price)::numeric(16, 2) as merchandise_revenue,
    sum(f.freight_value)::numeric(16, 2) as freight_value,
    sum(f.total_item_value)::numeric(16, 2) as gross_item_value,
    avg(f.item_price)::numeric(16, 2) as average_item_price
from {{ ref('fact_order_items') }} f
join {{ ref('dim_product') }} p on f.product_key = p.product_key
group by coalesce(p.category_name_english, 'Unknown')
