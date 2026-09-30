# Incremental Loading

## Architecture

```text
source.* (simulated OLTP)
    | updated_at > previous watermark
    v
raw.* immutable append + batch metadata
    |
    v
staging.* latest record per natural key
    |
    v
warehouse.* current Kimball model
```

## Watermark algorithm

Mỗi dataset có một record trong `audit.pipeline_watermarks`. Một ingestion transaction:

1. Khóa watermark hiện tại bằng `SELECT ... FOR UPDATE`.
2. Lấy database clock làm upper bound.
3. Chọn `previous_watermark < updated_at <= upper_bound`.
4. Append record vào RAW với `batch_id` và `source_updated_at`.
5. Cập nhật watermark.
6. Commit RAW append và watermark cùng lúc.

Nếu task lỗi trước commit, cả RAW records lẫn watermark đều rollback. Lần retry sẽ đọc lại đúng
khoảng dữ liệu đó.

## Local exercise

Khởi tạo source từ trạng thái warehouse hiện tại:

```powershell
olist-pipeline init-source
```

`init-source` là thao tác reset môi trường mô phỏng: nó seed lại source từ current-state staging
và đặt lại watermark. Không chạy lệnh này giữa các incremental runs nếu muốn giữ chuỗi thay đổi.

Tạo một order mới và một số source updates:

```powershell
olist-pipeline simulate-source
```

Chạy incremental bằng CLI:

```powershell
olist-pipeline ingest-incremental
olist-pipeline show-watermarks
olist-pipeline build-warehouse
olist-pipeline validate-warehouse
```

Hoặc trigger DAG `olist_incremental` trong Airflow. Task ingestion được dynamic-map thành sáu
task instances: customers, products, sellers, orders, order_items và payments.

Sau khi incremental append bắt đầu, tổng RAW có thể lớn hơn CSV gốc vì RAW giữ nhiều phiên bản
của cùng natural key. Vì vậy `olist-pipeline check-raw` chỉ dùng để đối chiếu ngay sau full
refresh; quality gate incremental so sánh warehouse với current-state staging.

## Current limitation

Ingestion vào RAW đã incremental và idempotent theo transaction/watermark. Warehouse vẫn được
rebuild từ current-state staging. Giai đoạn dbt tiếp theo sẽ chuyển facts/dimensions sang
incremental models và `MERGE`.
