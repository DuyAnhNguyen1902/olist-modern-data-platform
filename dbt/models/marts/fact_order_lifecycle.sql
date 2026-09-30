{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}

with item_totals as (
    select
        order_id,
        count(*)::integer as item_count,
        sum(price)::numeric(14, 2) as merchandise_value,
        sum(freight_value)::numeric(14, 2) as freight_value,
        max(record_updated_at) as record_updated_at
    from {{ ref('stg_order_items') }}
    group by order_id
),
payment_totals as (
    select
        order_id,
        sum(payment_value)::numeric(14, 2) as payment_value,
        max(record_updated_at) as record_updated_at
    from {{ ref('stg_payments') }}
    group by order_id
),
final as (
    select
        {{ stable_key('o.order_id') }} as order_key,
        o.order_id,
        coalesce(c.customer_key, -1) as customer_key,
        to_char(o.order_purchase_timestamp, 'YYYYMMDD')::integer as purchase_date_key,
        to_char(o.order_approved_at, 'YYYYMMDD')::integer as approved_date_key,
        to_char(o.order_delivered_customer_date, 'YYYYMMDD')::integer as delivered_date_key,
        to_char(o.order_estimated_delivery_date, 'YYYYMMDD')::integer as estimated_delivery_date_key,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        coalesce(i.item_count, 0) as item_count,
        coalesce(i.merchandise_value, 0)::numeric(14, 2) as merchandise_value,
        coalesce(i.freight_value, 0)::numeric(14, 2) as freight_value,
        coalesce(p.payment_value, 0)::numeric(14, 2) as payment_value,
        extract(epoch from (o.order_approved_at - o.order_purchase_timestamp)) / 60
            as approval_duration_minutes,
        extract(epoch from (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 3600
            as delivery_duration_hours,
        extract(epoch from (
            o.order_delivered_customer_date - o.order_estimated_delivery_date
        )) / 86400 as delivery_delay_days,
        case
            when o.order_delivered_customer_date is null then null
            else o.order_delivered_customer_date > o.order_estimated_delivery_date
        end as is_delivered_late,
        o.order_status = 'canceled' as is_cancelled,
        greatest(o.record_updated_at, i.record_updated_at, p.record_updated_at)
            as record_updated_at
    from {{ ref('stg_orders') }} o
    left join {{ ref('dim_customer') }} c on o.customer_id = c.customer_id
    left join item_totals i on o.order_id = i.order_id
    left join payment_totals p on o.order_id = p.order_id
)
select *
from final
{% if is_incremental() %}
where record_updated_at > (
    select coalesce(max(record_updated_at), '1970-01-01'::timestamptz) from {{ this }}
)
{% endif %}
