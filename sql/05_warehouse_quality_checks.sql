DO $$
DECLARE
    current_test_run_id TEXT := gen_random_uuid()::TEXT;
BEGIN
    INSERT INTO audit.data_quality_results (
        test_run_id, test_name, table_name, quality_dimension, severity,
        status, failed_rows, total_rows, failure_rate, error_message
    )
    SELECT
        current_test_run_id,
        'fact_order_items_grain_unique',
        'warehouse.fact_order_items',
        'uniqueness',
        'ERROR',
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'ERROR' END,
        COUNT(*),
        (SELECT COUNT(*) FROM warehouse.fact_order_items),
        CASE WHEN (SELECT COUNT(*) FROM warehouse.fact_order_items) = 0 THEN 0
             ELSE COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM warehouse.fact_order_items) END,
        'Duplicate grain: order_id + order_item_id'
    FROM (
        SELECT order_id, order_item_id
        FROM warehouse.fact_order_items
        GROUP BY order_id, order_item_id
        HAVING COUNT(*) > 1
    ) duplicates;

    INSERT INTO audit.data_quality_results (
        test_run_id, test_name, table_name, quality_dimension, severity,
        status, failed_rows, total_rows, failure_rate, error_message
    )
    SELECT
        current_test_run_id,
        'fact_order_items_row_reconciliation',
        'warehouse.fact_order_items',
        'consistency',
        'ERROR',
        CASE WHEN raw_count = fact_count THEN 'PASS' ELSE 'ERROR' END,
        ABS(raw_count - fact_count),
        raw_count,
        CASE WHEN raw_count = 0 THEN 0 ELSE ABS(raw_count - fact_count)::NUMERIC / raw_count END,
        'Fact row count must match current-state staging order item count'
    FROM (
        SELECT
            (SELECT COUNT(*) FROM staging.stg_order_items) AS raw_count,
            (SELECT COUNT(*) FROM warehouse.fact_order_items) AS fact_count
    ) counts;

    INSERT INTO audit.data_quality_results (
        test_run_id, test_name, table_name, quality_dimension, severity,
        status, failed_rows, total_rows, failure_rate, error_message
    )
    SELECT
        current_test_run_id,
        'fact_payments_row_reconciliation',
        'warehouse.fact_payments',
        'consistency',
        'ERROR',
        CASE WHEN raw_count = fact_count THEN 'PASS' ELSE 'ERROR' END,
        ABS(raw_count - fact_count),
        raw_count,
        CASE WHEN raw_count = 0 THEN 0 ELSE ABS(raw_count - fact_count)::NUMERIC / raw_count END,
        'Fact row count must match current-state staging payments count'
    FROM (
        SELECT
            (SELECT COUNT(*) FROM staging.stg_payments) AS raw_count,
            (SELECT COUNT(*) FROM warehouse.fact_payments) AS fact_count
    ) counts;

    INSERT INTO audit.data_quality_results (
        test_run_id, test_name, table_name, quality_dimension, severity,
        status, failed_rows, total_rows, failure_rate, error_message
    )
    SELECT
        current_test_run_id,
        'order_delivery_after_purchase',
        'warehouse.fact_order_lifecycle',
        'validity',
        'ERROR',
        CASE WHEN failed = 0 THEN 'PASS' ELSE 'ERROR' END,
        failed,
        total,
        CASE WHEN total = 0 THEN 0 ELSE failed::NUMERIC / total END,
        'Delivered timestamp cannot precede purchase timestamp'
    FROM (
        SELECT
            COUNT(*) FILTER (
                WHERE order_delivered_customer_date < order_purchase_timestamp
            ) AS failed,
            COUNT(*) AS total
        FROM warehouse.fact_order_lifecycle
    ) counts;

    INSERT INTO audit.data_quality_results (
        test_run_id, test_name, table_name, quality_dimension, severity,
        status, failed_rows, total_rows, failure_rate, error_message
    )
    SELECT
        current_test_run_id,
        'unknown_dimension_rate',
        'warehouse.fact_order_items',
        'integrity',
        'WARN',
        CASE WHEN failed::NUMERIC / NULLIF(total, 0) <= 0.01 THEN 'PASS' ELSE 'WARN' END,
        failed,
        total,
        COALESCE(failed::NUMERIC / NULLIF(total, 0), 0),
        'Unknown customer/product/seller keys should remain below 1%'
    FROM (
        SELECT
            COUNT(*) FILTER (
                WHERE customer_key = -1 OR product_key = -1 OR seller_key = -1
            ) AS failed,
            COUNT(*) AS total
        FROM warehouse.fact_order_items
    ) counts;

    INSERT INTO audit.data_quality_results (
        test_run_id, test_name, table_name, quality_dimension, severity,
        status, failed_rows, total_rows, failure_rate, error_message
    )
    SELECT
        current_test_run_id,
        'shipping_limit_reasonable',
        'staging.stg_order_items',
        'validity',
        'WARN',
        CASE WHEN failed = 0 THEN 'PASS' ELSE 'WARN' END,
        failed,
        total,
        COALESCE(failed::NUMERIC / NULLIF(total, 0), 0),
        'Shipping limit is more than 365 days after purchase; retained but flagged'
    FROM (
        SELECT
            COUNT(*) FILTER (
                WHERE i.shipping_limit_date > o.order_purchase_timestamp + INTERVAL '365 days'
            ) AS failed,
            COUNT(*) AS total
        FROM staging.stg_order_items i
        JOIN staging.stg_orders o ON i.order_id = o.order_id
    ) counts;
END $$;
