select
    (select count(*) from {{ ref('stg_order_items') }}) as staging_rows,
    (select count(*) from {{ ref('fact_order_items') }}) as fact_rows
where
    (select count(*) from {{ ref('stg_order_items') }})
    <>
    (select count(*) from {{ ref('fact_order_items') }})
