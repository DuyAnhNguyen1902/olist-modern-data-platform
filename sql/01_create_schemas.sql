CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS warehouse;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS source;

CREATE TABLE IF NOT EXISTS audit.load_history (
    load_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id         VARCHAR(36) NOT NULL,
    dataset_name     VARCHAR(100) NOT NULL,
    source_file      VARCHAR(255) NOT NULL,
    file_sha256      VARCHAR(64) NOT NULL,
    row_count        BIGINT NOT NULL,
    load_status      VARCHAR(20) NOT NULL,
    loaded_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit.data_quality_results (
    quality_result_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_run_id       VARCHAR(36) NOT NULL,
    test_name         VARCHAR(200) NOT NULL,
    table_name        VARCHAR(200) NOT NULL,
    quality_dimension VARCHAR(30) NOT NULL,
    severity          VARCHAR(10) NOT NULL,
    status            VARCHAR(10) NOT NULL,
    failed_rows       BIGINT NOT NULL,
    total_rows        BIGINT NOT NULL,
    failure_rate      NUMERIC(12, 6) NOT NULL,
    error_message     TEXT,
    executed_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit.pipeline_watermarks (
    dataset_name       VARCHAR(100) PRIMARY KEY,
    watermark_value    TIMESTAMPTZ NOT NULL,
    last_batch_id      VARCHAR(36),
    rows_extracted     BIGINT NOT NULL DEFAULT 0,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
