with ranked as (
    select
        *,
        row_number() over (
            partition by product_id
            order by source_updated_at desc nulls last, loaded_at desc
        ) as row_number
    from {{ source('raw', 'products') }}
)
select
    trim(product_id) as product_id,
    nullif(trim(product_category_name), '') as product_category_name,
    nullif(product_name_lenght, '')::integer as product_name_length,
    nullif(product_description_lenght, '')::integer as product_description_length,
    nullif(product_photos_qty, '')::integer as product_photos_quantity,
    nullif(product_weight_g, '')::numeric(12, 2) as product_weight_g,
    nullif(product_length_cm, '')::numeric(12, 2) as product_length_cm,
    nullif(product_height_cm, '')::numeric(12, 2) as product_height_cm,
    nullif(product_width_cm, '')::numeric(12, 2) as product_width_cm,
    coalesce(source_updated_at, loaded_at) as record_updated_at
from ranked
where row_number = 1
