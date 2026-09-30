from __future__ import annotations

import uuid

import psycopg

from .database import RAW_TABLES, run_sql_file
from .quality import load_contract
from .settings import PROJECT_ROOT, Settings

INCREMENTAL_DATASETS = (
    "customers",
    "products",
    "sellers",
    "orders",
    "order_items",
    "payments",
)


def initialize_source(settings: Settings) -> None:
    """Create and seed the simulated OLTP source, then set baseline watermarks."""
    with psycopg.connect(settings.postgres_dsn) as connection:
        run_sql_file(connection, PROJECT_ROOT / "sql/06_create_source_tables.sql")
        run_sql_file(connection, PROJECT_ROOT / "sql/07_seed_source.sql")


def simulate_source_changes(settings: Settings) -> dict:
    """Create one new transaction and two updates for incremental-ingestion practice."""
    suffix = uuid.uuid4().hex[:12]
    customer_id = f"sim-customer-{suffix}"
    order_id = f"sim-order-{suffix}"

    with psycopg.connect(settings.postgres_dsn) as connection, connection.cursor() as cursor:
        cursor.execute("SELECT clock_timestamp()")
        changed_at = cursor.fetchone()[0]
        cursor.execute("SELECT product_id FROM source.products ORDER BY product_id LIMIT 1")
        product_id = cursor.fetchone()[0]
        cursor.execute("SELECT seller_id FROM source.sellers ORDER BY seller_id LIMIT 1")
        seller_id = cursor.fetchone()[0]

        cursor.execute(
            """
                INSERT INTO source.customers (
                    customer_id, customer_unique_id, customer_zip_code_prefix,
                    customer_city, customer_state, updated_at
                ) VALUES (%s, %s, 1003, 'sao paulo', 'SP', %s)
                """,
            (customer_id, customer_id, changed_at),
        )
        cursor.execute(
            """
                INSERT INTO source.orders (
                    order_id, customer_id, order_status, order_purchase_timestamp,
                    order_approved_at, order_estimated_delivery_date, updated_at
                ) VALUES (
                    %s, %s, 'approved', %s, %s,
                    %s + INTERVAL '7 days', %s
                )
                """,
            (order_id, customer_id, changed_at, changed_at, changed_at, changed_at),
        )
        cursor.execute(
            """
                INSERT INTO source.order_items (
                    order_id, order_item_id, product_id, seller_id,
                    shipping_limit_date, price, freight_value, updated_at
                ) VALUES (%s, 1, %s, %s, %s + INTERVAL '2 days', 99.90, 10.00, %s)
                """,
            (order_id, product_id, seller_id, changed_at, changed_at),
        )
        cursor.execute(
            """
                INSERT INTO source.payments (
                    order_id, payment_sequential, payment_type,
                    payment_installments, payment_value, updated_at
                ) VALUES (%s, 1, 'credit_card', 1, 109.90, %s)
                """,
            (order_id, changed_at),
        )
        cursor.execute(
            """
                UPDATE source.products
                SET product_description_lenght = COALESCE(product_description_lenght, 0) + 1,
                    updated_at = %s
                WHERE product_id = %s
                """,
            (changed_at, product_id),
        )
        cursor.execute(
            """
                UPDATE source.customers
                SET customer_city = customer_city,
                    updated_at = %s
                WHERE customer_id = (
                    SELECT customer_id
                    FROM source.customers
                    WHERE customer_id NOT LIKE 'sim-customer-%%'
                    ORDER BY customer_id
                    LIMIT 1
                )
                """,
            (changed_at,),
        )

    return {
        "changed_at": changed_at.isoformat(),
        "customer_id": customer_id,
        "order_id": order_id,
        "product_id": product_id,
        "seller_id": seller_id,
    }


def ingest_incremental_dataset(settings: Settings, dataset_name: str) -> dict:
    """Atomically append changed rows to RAW and advance a per-dataset watermark."""
    if dataset_name not in INCREMENTAL_DATASETS:
        raise ValueError(f"Dataset không hỗ trợ incremental: {dataset_name}")

    contract = load_contract(settings.quality_config)
    columns = contract["datasets"][dataset_name]["required_columns"]
    target_table = RAW_TABLES[dataset_name]
    source_table = f"source.{dataset_name}"
    batch_id = str(uuid.uuid4())
    source_uri = f"postgres://{source_table}"
    epoch = "1970-01-01T00:00:00+00:00"

    with psycopg.connect(settings.postgres_dsn) as connection, connection.cursor() as cursor:
        cursor.execute(
            """
                SELECT watermark_value
                FROM audit.pipeline_watermarks
                WHERE dataset_name = %s
                FOR UPDATE
                """,
            (dataset_name,),
        )
        row = cursor.fetchone()
        previous_watermark = row[0] if row else epoch
        cursor.execute("SELECT clock_timestamp()")
        extraction_upper_bound = cursor.fetchone()[0]

        target_columns = ", ".join(columns)
        source_columns = ", ".join(f"{column}::TEXT" for column in columns)
        cursor.execute(
            f"""
                INSERT INTO {target_table} (
                    {target_columns}, source_file, batch_id, source_updated_at
                )
                SELECT
                    {source_columns}, %s, %s, updated_at
                FROM {source_table}
                WHERE updated_at > %s
                  AND updated_at <= %s
                ORDER BY updated_at
                """,
            (source_uri, batch_id, previous_watermark, extraction_upper_bound),
        )
        rows_extracted = cursor.rowcount
        cursor.execute(
            """
                INSERT INTO audit.pipeline_watermarks (
                    dataset_name, watermark_value, last_batch_id,
                    rows_extracted, updated_at
                ) VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP)
                ON CONFLICT (dataset_name) DO UPDATE SET
                    watermark_value = EXCLUDED.watermark_value,
                    last_batch_id = EXCLUDED.last_batch_id,
                    rows_extracted = EXCLUDED.rows_extracted,
                    updated_at = CURRENT_TIMESTAMP
                """,
            (dataset_name, extraction_upper_bound, batch_id, rows_extracted),
        )
        cursor.execute(
            """
                INSERT INTO audit.load_history (
                    batch_id, dataset_name, source_file, file_sha256,
                    row_count, load_status, loaded_at
                ) VALUES (%s, %s, %s, 'NOT_APPLICABLE', %s, 'SUCCESS', CURRENT_TIMESTAMP)
                """,
            (batch_id, dataset_name, source_uri, rows_extracted),
        )

    return {
        "dataset": dataset_name,
        "batch_id": batch_id,
        "rows_extracted": rows_extracted,
        "previous_watermark": str(previous_watermark),
        "new_watermark": extraction_upper_bound.isoformat(),
    }


def get_watermarks(settings: Settings) -> list[dict]:
    with psycopg.connect(settings.postgres_dsn) as connection, connection.cursor() as cursor:
        cursor.execute(
            """
                SELECT dataset_name, watermark_value, rows_extracted,
                       last_batch_id, updated_at
                FROM audit.pipeline_watermarks
                ORDER BY dataset_name
                """
        )
        return [
            {
                "dataset": row[0],
                "watermark": row[1],
                "rows_extracted": row[2],
                "last_batch_id": row[3],
                "updated_at": row[4],
            }
            for row in cursor.fetchall()
        ]
