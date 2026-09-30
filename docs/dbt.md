# dbt Transformations

## Mục tiêu

dbt chịu trách nhiệm cho toàn bộ phần transform sau RAW. Python/Airflow chỉ orchestration và
ingestion; business logic, lineage và model tests nằm trong thư mục `dbt/`.

## Layers

```text
raw.*
  -> staging_dbt.stg_*
  -> warehouse_dbt.dim_*
  -> warehouse_dbt.fact_*
```

Staging được materialize thành view. `dim_customer`, `dim_product`, `dim_seller` và ba fact
được materialize incremental bằng strategy `delete+insert`. `dim_date` nhỏ nên được build lại.
Surrogate keys được tạo ổn định từ MD5 của natural key; `-1` dành cho unknown member.

## Commands

```powershell
olist-pipeline dbt-debug
olist-pipeline dbt-build --full-refresh
olist-pipeline dbt-build
```

Bạn cũng có thể dùng dbt CLI trực tiếp:

```powershell
dbt build --project-dir dbt --profiles-dir dbt
dbt docs generate --project-dir dbt --profiles-dir dbt
dbt docs serve --project-dir dbt --profiles-dir dbt
```

Kết nối trong `profiles.yml` chỉ đọc credentials từ environment variables; không hard-code
secret thật. Local host dùng port 5433, container Airflow dùng hostname `postgres`, port 5432.

## Quality gates

`dbt build` dừng ngay khi generic hoặc singular test cấp ERROR thất bại. Các test chính:

- Primary grain uniqueness và not-null.
- Relationships giữa fact và conformed dimensions.
- Accepted order status.
- Reconciliation số dòng staging/fact.
- Delivery không được trước purchase.
- Unknown dimension rate tối đa 1% (WARN).
- Shipping limit bất thường trên 365 ngày (WARN và lưu failure rows).

## Airflow

- `olist_full_refresh`: load lại RAW rồi chạy `dbt build --full-refresh`.
- `olist_incremental`: ingest theo watermark rồi chạy `dbt build`.

dbt output được đưa vào Airflow task logs, nên một test thất bại sẽ làm task và DAG fail.

## Documentation và lineage

Docker Compose có service `dbt-docs`, tự chạy `dbt docs generate` và phục vụ giao diện local:

```text
http://localhost:8081
```

Lineage được hình thành từ các lời gọi `source()` và `ref()` trong models. Sau khi sửa SQL hoặc
YAML description, chạy `docker compose restart dbt-docs` để tạo lại catalog. Đây là local
development server; không public trực tiếp port 8081 ra Internet.
