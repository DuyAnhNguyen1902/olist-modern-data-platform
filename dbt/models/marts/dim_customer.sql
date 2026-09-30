{{ config(
    materialized='incremental',
    unique_key='customer_key',
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}

with customer_rows as (
    select
        {{ stable_key('c.customer_id') }} as customer_key,
        c.customer_id,
        c.customer_unique_id,
        c.customer_zip_code_prefix as zip_code_prefix,
        c.customer_city as city,
        c.customer_state as state,
        g.latitude,
        g.longitude,
        greatest(c.record_updated_at, g.record_updated_at) as record_updated_at
    from {{ ref('stg_customers') }} c
    left join {{ ref('stg_geolocation') }} g
        on c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
    {% if is_incremental() %}
    where c.record_updated_at > (
        select coalesce(max(record_updated_at), '1970-01-01'::timestamptz) from {{ this }}
    )
    {% endif %}
)
select * from customer_rows
{% if not is_incremental() %}
union all
select
    -1::bigint, 'UNKNOWN', 'UNKNOWN', null::integer, 'Unknown', 'Unknown',
    null::double precision, null::double precision, '1970-01-01'::timestamptz
{% endif %}
