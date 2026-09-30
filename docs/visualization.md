# Visualization with Metabase

## BI architecture

```text
warehouse_dbt dimensions + facts
              |
              v
analytics_dbt presentation marts
              |
              v
Metabase dashboard (localhost:3000)
```

Metabase connects with the read-only role `metabase_reader`. The role can query only
`analytics_dbt` and `warehouse_dbt`; it cannot modify data or read RAW/source tables.

## Presentation marts

| Model | Grain | Dashboard use |
|---|---|---|
| `mart_executive_kpis` | One all-time row | KPI cards |
| `mart_sales_daily` | One row per purchase date | Revenue/order trend |
| `mart_category_performance` | One row per product category | Top categories |
| `mart_state_performance` | One row per customer state | Geographic performance |
| `mart_order_status` | One row per order status | Status distribution |

Revenue in order-level marts uses `fact_order_lifecycle.payment_value`, preventing the
many-to-many multiplication that would occur by directly joining items to payments.

## Start the BI layer

```powershell
docker compose exec airflow olist-pipeline init-bi
docker compose exec airflow olist-pipeline dbt-build
docker compose up -d metabase
```

Open `http://localhost:3000` and complete the initial local admin setup. Add a PostgreSQL
database with these local-development settings:

| Setting | Value |
|---|---|
| Display name | Olist Analytics |
| Host | `postgres` |
| Port | `5432` |
| Database | `ecommerce` |
| Username | `metabase_reader` |
| Password | `metabase_dev` |

Use the values from `.env` instead if you changed `BI_USER` or `BI_PASSWORD`.

## Recommended dashboard

Create a dashboard named **Olist E-commerce Performance** with:

1. Number card — Total Revenue.
2. Number card — Total Orders.
3. Number card — Average Order Value.
4. Number card — Late Delivery Rate.
5. Line chart — Revenue and Orders by `full_date`.
6. Horizontal bar chart — Top 10 categories by `merchandise_revenue`.
7. Bar or map chart — Revenue by `customer_state`.
8. Donut chart — Order count by `order_status`.
9. Bar chart — Top states by late-delivery rate, limited to states with at least 100 orders.

Add date and state filters after the first version works. Format monetary values as BRL and rate
fields as percentages. Dashboard definitions are stored in the `metabase_data` Docker volume.

The incremental end-to-end test intentionally creates a synthetic order with a current purchase
date. Historical Olist charts should filter `full_date < date '2019-01-01'` so test evidence does
not distort the time axis. Keep the synthetic row in the database to demonstrate incremental
loading instead of deleting it.

## Portfolio screenshots

Capture three images for the README later:

- Executive dashboard.
- Airflow successful incremental DAG.
- dbt lineage graph.

Store the final files under `docs/images/`. Do not include account credentials or unrelated
browser content in the screenshots.
