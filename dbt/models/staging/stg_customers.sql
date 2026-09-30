with ranked as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by source_updated_at desc nulls last, loaded_at desc
        ) as row_number
    from {{ source('raw', 'customers') }}
)
select
    trim(customer_id) as customer_id,
    trim(customer_unique_id) as customer_unique_id,
    nullif(customer_zip_code_prefix, '')::integer as customer_zip_code_prefix,
    nullif(trim(customer_city), '') as customer_city,
    nullif(trim(customer_state), '') as customer_state,
    coalesce(source_updated_at, loaded_at) as record_updated_at
from ranked
where row_number = 1
