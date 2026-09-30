select
    nullif(geolocation_zip_code_prefix, '')::integer as geolocation_zip_code_prefix,
    avg(nullif(geolocation_lat, '')::double precision) as latitude,
    avg(nullif(geolocation_lng, '')::double precision) as longitude,
    min(nullif(trim(geolocation_city), '')) as city,
    min(nullif(trim(geolocation_state), '')) as state,
    max(coalesce(source_updated_at, loaded_at)) as record_updated_at
from {{ source('raw', 'geolocation') }}
group by nullif(geolocation_zip_code_prefix, '')::integer
