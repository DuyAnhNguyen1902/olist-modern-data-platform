select
    trim(product_category_name) as product_category_name,
    trim(product_category_name_english) as product_category_name_english,
    coalesce(source_updated_at, loaded_at) as record_updated_at
from {{ source('raw', 'category_translation') }}
