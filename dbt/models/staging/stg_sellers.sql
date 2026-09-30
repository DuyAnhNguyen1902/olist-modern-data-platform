with ranked as (
    select
        *,
        row_number() over (
            partition by seller_id
            order by source_updated_at desc nulls last, loaded_at desc
        ) as row_number
    from {{ source('raw', 'sellers') }}
)
select
    trim(seller_id) as seller_id,
    nullif(seller_zip_code_prefix, '')::integer as seller_zip_code_prefix,
    nullif(trim(seller_city), '') as seller_city,
    nullif(trim(seller_state), '') as seller_state,
    coalesce(source_updated_at, loaded_at) as record_updated_at
from ranked
where row_number = 1
