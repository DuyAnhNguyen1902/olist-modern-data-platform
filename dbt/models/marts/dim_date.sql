with source_dates as (
    select order_purchase_timestamp::date as source_date from {{ ref('stg_orders') }}
    union all
    select order_approved_at::date from {{ ref('stg_orders') }}
    union all
    select order_delivered_carrier_date::date from {{ ref('stg_orders') }}
    union all
    select order_delivered_customer_date::date from {{ ref('stg_orders') }}
    union all
    select order_estimated_delivery_date::date from {{ ref('stg_orders') }}
    union all
    select shipping_limit_date::date from {{ ref('stg_order_items') }}
),
boundaries as (
    select min(source_date) as min_date, max(source_date) as max_date
    from source_dates
    where source_date is not null
)
select
    to_char(calendar_date, 'YYYYMMDD')::integer as date_key,
    calendar_date::date as full_date,
    extract(day from calendar_date)::smallint as day_of_month,
    extract(isodow from calendar_date)::smallint as day_of_week,
    trim(to_char(calendar_date, 'Day')) as day_name,
    extract(week from calendar_date)::smallint as week_of_year,
    extract(month from calendar_date)::smallint as month_number,
    trim(to_char(calendar_date, 'Month')) as month_name,
    extract(quarter from calendar_date)::smallint as quarter_number,
    extract(year from calendar_date)::smallint as year_number,
    extract(isodow from calendar_date) in (6, 7) as is_weekend
from boundaries
cross join lateral generate_series(min_date, max_date, interval '1 day') as dates(calendar_date)
