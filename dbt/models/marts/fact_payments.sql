{{ config(
    materialized='incremental',
    unique_key=['order_id', 'payment_sequential'],
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}

select
    {{ stable_key("p.order_id || '|' || p.payment_sequential::text") }} as payment_key,
    p.order_id,
    p.payment_sequential,
    coalesce(c.customer_key, -1) as customer_key,
    to_char(o.order_purchase_timestamp, 'YYYYMMDD')::integer as payment_date_key,
    p.payment_type,
    p.payment_installments as installment_count,
    p.payment_value,
    greatest(p.record_updated_at, o.record_updated_at) as record_updated_at
from {{ ref('stg_payments') }} p
join {{ ref('stg_orders') }} o on p.order_id = o.order_id
left join {{ ref('dim_customer') }} c on o.customer_id = c.customer_id
{% if is_incremental() %}
where greatest(p.record_updated_at, o.record_updated_at) > (
    select coalesce(max(record_updated_at), '1970-01-01'::timestamptz) from {{ this }}
)
{% endif %}
