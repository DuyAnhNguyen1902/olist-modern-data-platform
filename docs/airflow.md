# Airflow Orchestration

## Mục tiêu

DAG `olist_full_refresh` thay thế chuỗi lệnh thủ công bằng một workflow có trạng thái, log,
retry, timeout và quality gates. DAG chỉ chạy khi được trigger thủ công vì mỗi run sẽ rebuild
toàn bộ RAW và warehouse.

## Task graph

```text
profile_source
  -> validate_source
  -> initialize_postgres
  -> load_raw_full_refresh
  -> reconcile_raw
  -> build_and_test_dbt
```

## Failure behavior

- Source có lỗi cấp `ERROR`: dừng trước khi chạm database.
- Một CSV load lỗi: toàn bộ RAW transaction rollback.
- CSV và RAW lệch row count: không chạy dbt.
- dbt model hoặc test cấp `ERROR` thất bại: DAG failed.
- dbt test cấp `WARN`: DAG thành công, failure rows nằm trong `dbt_test_failures`.
- Database task lỗi tạm thời được retry theo cấu hình DAG.

## Vì sao dùng standalone

Đây là môi trường local dành cho học tập. Airflow standalone gom các component, dùng SQLite
cho metadata và LocalExecutor để thực thi task. PostgreSQL `ecommerce` vẫn là database dữ liệu
của pipeline, hoàn toàn tách khỏi Airflow metadata.

Khi chuyển sang production-style deployment, tách API server, scheduler, DAG processor,
triggerer và metadata PostgreSQL thành các service riêng.

## Chạy

```powershell
docker compose up -d --build
docker compose ps
```

UI: `http://localhost:8080`

Trigger bằng CLI:

```powershell
docker compose exec airflow airflow dags trigger olist_full_refresh
```

Theo dõi log:

```powershell
docker compose logs -f airflow
```
