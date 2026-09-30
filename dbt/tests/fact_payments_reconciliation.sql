select
    (select count(*) from {{ ref('stg_payments') }}) as staging_rows,
    (select count(*) from {{ ref('fact_payments') }}) as fact_rows
where
    (select count(*) from {{ ref('stg_payments') }})
    <>
    (select count(*) from {{ ref('fact_payments') }})
