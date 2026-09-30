{{ config(
    materialized='incremental',
    unique_key='product_key',
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}

with product_rows as (
    select
        {{ stable_key('p.product_id') }} as product_key,
        p.product_id,
        p.product_category_name as category_name,
        coalesce(t.product_category_name_english, p.product_category_name) as category_name_english,
        p.product_name_length,
        p.product_description_length,
        p.product_photos_quantity,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,
        greatest(p.record_updated_at, t.record_updated_at) as record_updated_at
    from {{ ref('stg_products') }} p
    left join {{ ref('stg_category_translation') }} t
        on p.product_category_name = t.product_category_name
    {% if is_incremental() %}
    where p.record_updated_at > (
        select coalesce(max(record_updated_at), '1970-01-01'::timestamptz) from {{ this }}
    )
    {% endif %}
)
select * from product_rows
{% if not is_incremental() %}
union all
select
    -1::bigint, 'UNKNOWN', 'Unknown', 'Unknown', null::integer, null::integer,
    null::integer, null::numeric, null::numeric, null::numeric, null::numeric,
    '1970-01-01'::timestamptz
{% endif %}
