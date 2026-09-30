# Delivery Roadmap

Mỗi giai đoạn phải chạy được độc lập trước khi thêm công nghệ tiếp theo.

## Phase 1 — PostgreSQL + Python + Kimball (hiện tại)

- Data profiling và data contracts.
- Raw, staging, warehouse và audit schemas.
- Ba fact tables, bốn dimensions.
- Reconciliation và data quality gates.

Definition of done: toàn bộ CSV được load, warehouse build thành công và không có quality
check cấp `ERROR`.

## Phase 2 — Airflow + Docker (đã triển khai bản local)

- DAG: validate → load raw → transform → quality gate → publish.
- Retry, timeout, backfill, logging và failure notification.
- Một DAG run tương ứng một batch date.

Đã bổ sung PostgreSQL source mô phỏng, incremental extraction bằng watermark và Airflow dynamic
task mapping. Warehouse transformation vẫn full rebuild và sẽ được chuyển sang incremental dbt.

## Phase 3 — dbt (đã triển khai local)

- Staging và Kimball marts dưới dạng dbt models.
- Generic tests, singular tests, sources, docs và lineage.
- Incremental materialization với deterministic surrogate keys.
- `dbt build` là quality gate trong cả hai Airflow DAG.

## Phase 4 — Snowflake

- PostgreSQL giữ vai trò OLTP source.
- Extract thành Parquet/CSV, upload stage và `COPY INTO` Snowflake.
- Incremental load bằng watermark và `MERGE`.
- X-Small warehouse, auto-suspend và cost monitor.

## Phase 5 — MinIO/S3

- Raw immutable zone, partition theo ingestion date.
- Replay và backfill từ raw files.
- So sánh CSV với Parquet.

## Phase 6 — Kafka/Redpanda

- Event generator: view, cart, checkout, payment.
- Producer, consumer group, offset và dead-letter topic.
- Idempotent event ingestion và late-event handling.

## Phase 7 — Spark

- Sinh 5–20 triệu events.
- PySpark transformations, partitioning và benchmark.
- Không dùng Spark cho bảng nhỏ chỉ để thêm tên công nghệ.

## Phase 8 — CI/CD + observability

- GitHub Actions chạy Python tests, lint và dbt tests.
- Freshness, volume, failure rate và pipeline duration dashboard.
- Architecture diagram, runbook, demo video và interview notes.
