with ranked as (
    select
        *,
        row_number() over (
            partition by order_id, payment_sequential
            order by source_updated_at desc nulls last, loaded_at desc
        ) as row_number
    from {{ source('raw', 'payments') }}
)
select
    trim(order_id) as order_id,
    nullif(payment_sequential, '')::integer as payment_sequential,
    lower(trim(payment_type)) as payment_type,
    nullif(payment_installments, '')::integer as payment_installments,
    nullif(payment_value, '')::numeric(12, 2) as payment_value,
    coalesce(source_updated_at, loaded_at) as record_updated_at
from ranked
where row_number = 1
