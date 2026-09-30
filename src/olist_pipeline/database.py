from __future__ import annotations

import csv
import hashlib
import json
import uuid
from datetime import UTC, datetime
from pathlib import Path

from .settings import PROJECT_ROOT, Settings

RAW_TABLES = {
    "customers": "raw.customers",
    "orders": "raw.orders",
    "order_items": "raw.order_items",
    "payments": "raw.payments",
    "reviews": "raw.reviews",
    "products": "raw.products",
    "sellers": "raw.sellers",
    "geolocation": "raw.geolocation",
    "category_translation": "raw.category_translation",
}


def run_sql_file(connection, path: Path) -> None:
    sql_text = path.read_text(encoding="utf-8")
    with connection.cursor() as cursor:
        cursor.execute(sql_text)
    connection.commit()


def initialize_database(settings: Settings) -> None:
    import psycopg

    with psycopg.connect(settings.postgres_dsn) as connection:
        run_sql_file(connection, PROJECT_ROOT / "sql/01_create_schemas.sql")
        run_sql_file(connection, PROJECT_ROOT / "sql/02_create_raw_tables.sql")
        run_sql_file(connection, PROJECT_ROOT / "sql/03_create_staging_views.sql")
    initialize_bi_access(settings)


def initialize_bi_access(settings: Settings) -> None:
    """Create a least-privilege login for BI tools and grant read-only mart access."""
    import psycopg
    from psycopg import sql

    role = sql.Identifier(settings.bi_user)
    with psycopg.connect(settings.postgres_dsn) as connection, connection.cursor() as cursor:
        cursor.execute(
            "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = %s)", (settings.bi_user,)
        )
        if not cursor.fetchone()[0]:
            cursor.execute(
                sql.SQL("CREATE ROLE {} LOGIN PASSWORD {}").format(
                    role, sql.Literal(settings.bi_password)
                )
            )
        else:
            cursor.execute(
                sql.SQL("ALTER ROLE {} WITH LOGIN PASSWORD {}").format(
                    role, sql.Literal(settings.bi_password)
                )
            )

        cursor.execute("CREATE SCHEMA IF NOT EXISTS analytics_dbt")
        cursor.execute("CREATE SCHEMA IF NOT EXISTS warehouse_dbt")
        cursor.execute(
            sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(
                sql.Identifier(settings.postgres_db), role
            )
        )
        for schema_name in ("analytics_dbt", "warehouse_dbt"):
            schema = sql.Identifier(schema_name)
            cursor.execute(sql.SQL("GRANT USAGE ON SCHEMA {} TO {}").format(schema, role))
            cursor.execute(
                sql.SQL("GRANT SELECT ON ALL TABLES IN SCHEMA {} TO {}").format(schema, role)
            )
            cursor.execute(
                sql.SQL(
                    "ALTER DEFAULT PRIVILEGES IN SCHEMA {} GRANT SELECT ON TABLES TO {}"
                ).format(schema, role)
            )


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_raw_data(settings: Settings, replace: bool = False) -> None:
    import psycopg

    contract = json.loads(settings.quality_config.read_text(encoding="utf-8"))
    batch_id = str(uuid.uuid4())

    with psycopg.connect(settings.postgres_dsn) as connection:
        for dataset_name, spec in contract["datasets"].items():
            table = RAW_TABLES[dataset_name]
            path = settings.data_dir / spec["file"]
            if not path.exists():
                raise FileNotFoundError(path)

            with connection.cursor() as cursor:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                existing_rows = cursor.fetchone()[0]
                if existing_rows and not replace:
                    raise RuntimeError(
                        f"{table} đã có {existing_rows:,} dòng. Dùng --replace nếu muốn nạp lại."
                    )
                if replace:
                    cursor.execute(f"TRUNCATE TABLE {table}")

                columns = spec["required_columns"]
                column_sql = ", ".join(columns)
                copy_sql = (
                    f"COPY {table} ({column_sql}) FROM STDIN "
                    "WITH (FORMAT CSV, HEADER TRUE, NULL '', ENCODING 'UTF8')"
                )
                with (
                    path.open("r", encoding="utf-8", newline="") as stream,
                    cursor.copy(copy_sql) as copy,
                ):
                    while chunk := stream.read(1024 * 1024):
                        copy.write(chunk)

                cursor.execute(
                    f"""
                    UPDATE {table}
                    SET source_file = %s, batch_id = %s
                    WHERE batch_id IS NULL
                    """,
                    (path.name, batch_id),
                )
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                loaded_rows = cursor.fetchone()[0]
                cursor.execute(
                    """
                    INSERT INTO audit.load_history (
                        batch_id, dataset_name, source_file, file_sha256,
                        row_count, load_status, loaded_at
                    ) VALUES (%s, %s, %s, %s, %s, 'SUCCESS', %s)
                    """,
                    (
                        batch_id,
                        dataset_name,
                        path.name,
                        _sha256(path),
                        loaded_rows,
                        datetime.now(UTC),
                    ),
                )
        # Commit once after every dataset succeeds. If any COPY fails, psycopg rolls the
        # entire load back so RAW never remains in a partially loaded state.


def _csv_row_count(path: Path) -> int:
    with path.open("r", encoding="utf-8", newline="") as stream:
        return sum(1 for _ in csv.reader(stream)) - 1


def reconcile_raw_counts(settings: Settings) -> list[dict]:
    """Compare source CSV counts with RAW table counts for every contracted dataset."""
    import psycopg

    contract = json.loads(settings.quality_config.read_text(encoding="utf-8"))
    results: list[dict] = []

    with psycopg.connect(settings.postgres_dsn) as connection, connection.cursor() as cursor:
        for dataset_name, spec in contract["datasets"].items():
            cursor.execute(f"SELECT COUNT(*) FROM {RAW_TABLES[dataset_name]}")
            database_count = cursor.fetchone()[0]
            source_count = _csv_row_count(settings.data_dir / spec["file"])
            results.append(
                {
                    "dataset": dataset_name,
                    "source_count": source_count,
                    "database_count": database_count,
                    "status": "PASS" if source_count == database_count else "ERROR",
                }
            )
    return results


def build_warehouse(settings: Settings) -> None:
    import psycopg

    with psycopg.connect(settings.postgres_dsn) as connection:
        run_sql_file(connection, PROJECT_ROOT / "sql/04_build_warehouse.sql")


def validate_warehouse(settings: Settings) -> list[tuple]:
    import psycopg

    with psycopg.connect(settings.postgres_dsn) as connection:
        run_sql_file(connection, PROJECT_ROOT / "sql/05_warehouse_quality_checks.sql")
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT test_name, table_name, quality_dimension, status,
                       failed_rows, total_rows, executed_at
                FROM audit.data_quality_results
                WHERE test_run_id = (
                    SELECT test_run_id
                    FROM audit.data_quality_results
                    ORDER BY executed_at DESC
                    LIMIT 1
                )
                ORDER BY status DESC, test_name
                """
            )
            return cursor.fetchall()
