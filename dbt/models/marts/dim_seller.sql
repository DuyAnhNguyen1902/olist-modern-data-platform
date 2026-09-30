{{ config(
    materialized='incremental',
    unique_key='seller_key',
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}

with seller_rows as (
    select
        {{ stable_key('s.seller_id') }} as seller_key,
        s.seller_id,
        s.seller_zip_code_prefix as zip_code_prefix,
        s.seller_city as city,
        s.seller_state as state,
        g.latitude,
        g.longitude,
        greatest(s.record_updated_at, g.record_updated_at) as record_updated_at
    from {{ ref('stg_sellers') }} s
    left join {{ ref('stg_geolocation') }} g
        on s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
    {% if is_incremental() %}
    where s.record_updated_at > (
        select coalesce(max(record_updated_at), '1970-01-01'::timestamptz) from {{ this }}
    )
    {% endif %}
)
select * from seller_rows
{% if not is_incremental() %}
union all
select
    -1::bigint, 'UNKNOWN', null::integer, 'Unknown', 'Unknown',
    null::double precision, null::double precision, '1970-01-01'::timestamptz
{% endif %}
