# End-to-End Incremental Validation

Validation date: 2026-09-30 (UTC)

## Scenario

1. Capture baseline RAW and `warehouse_dbt` counts.
2. Create one simulated order with one item and one payment.
3. Trigger Airflow DAG `olist_incremental` through the REST API.
4. Verify watermark extraction and trace the order through every layer.
5. Trigger the same DAG again without changing the source to prove idempotency.

Test order: `sim-order-cdff18b4447e`

## First run

Airflow run: `manual__e2e_20260930T010429Z` — **SUCCESS**

Watermark extraction:

| Dataset | Rows extracted |
|---|---:|
| customers | 2 |
| products | 1 |
| sellers | 0 |
| orders | 1 |
| order_items | 1 |
| payments | 1 |

The customer count is 2 because the simulator creates one customer and updates one existing
customer. The product count is 1 because it updates an existing product.

Order trace:

| Layer | Matching rows |
|---|---:|
| `source.orders` | 1 |
| `raw.orders` | 1 |
| `staging_dbt.stg_orders` | 1 |
| `warehouse_dbt.fact_order_lifecycle` | 1 |
| `warehouse_dbt.fact_order_items` | 1 |
| `warehouse_dbt.fact_payments` | 1 |

Final warehouse counts after the first run:

| Model | Rows |
|---|---:|
| `dim_customer` | 99,444 |
| `fact_order_lifecycle` | 99,443 |
| `fact_order_items` | 112,652 |
| `fact_payments` | 103,888 |

All Airflow tasks, dbt models, and dbt ERROR-level tests passed. The known four-row
`shipping_limit_reasonable` test remained WARN-only.

## Idempotency run

Airflow run: `manual__idempotency_20260930T0106Z` — **SUCCESS**

All six incremental datasets extracted zero rows. Final warehouse counts were identical to the
first run, proving that replaying the pipeline without new source changes does not create
duplicate facts or dimensions.

## Acceptance result

**PASS** — the pipeline demonstrates watermark-based extraction, atomic watermark advancement,
dynamic Airflow task mapping, incremental dbt upserts, automated quality gates, end-to-end
traceability, and idempotent replay.
