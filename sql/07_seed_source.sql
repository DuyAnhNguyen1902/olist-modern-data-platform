TRUNCATE TABLE
    source.payments,
    source.order_items,
    source.orders,
    source.customers,
    source.products,
    source.sellers
CASCADE;

INSERT INTO source.customers (
    customer_id, customer_unique_id, customer_zip_code_prefix,
    customer_city, customer_state
)
SELECT
    customer_id, customer_unique_id, customer_zip_code_prefix,
    customer_city, customer_state
FROM staging.stg_customers;

INSERT INTO source.products (
    product_id, product_category_name, product_name_lenght,
    product_description_lenght, product_photos_qty, product_weight_g,
    product_length_cm, product_height_cm, product_width_cm
)
SELECT
    product_id, product_category_name, product_name_length,
    product_description_length, product_photos_quantity, product_weight_g,
    product_length_cm, product_height_cm, product_width_cm
FROM staging.stg_products;

INSERT INTO source.sellers (
    seller_id, seller_zip_code_prefix, seller_city, seller_state
)
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM staging.stg_sellers;

INSERT INTO source.orders (
    order_id, customer_id, order_status, order_purchase_timestamp,
    order_approved_at, order_delivered_carrier_date,
    order_delivered_customer_date, order_estimated_delivery_date
)
SELECT
    order_id, customer_id, order_status, order_purchase_timestamp,
    order_approved_at, order_delivered_carrier_date,
    order_delivered_customer_date, order_estimated_delivery_date
FROM staging.stg_orders;

INSERT INTO source.order_items (
    order_id, order_item_id, product_id, seller_id, shipping_limit_date,
    price, freight_value
)
SELECT
    order_id, order_item_id, product_id, seller_id, shipping_limit_date,
    price, freight_value
FROM staging.stg_order_items;

INSERT INTO source.payments (
    order_id, payment_sequential, payment_type, payment_installments, payment_value
)
SELECT
    order_id, payment_sequential, payment_type, payment_installments, payment_value
FROM staging.stg_payments;

INSERT INTO audit.pipeline_watermarks (
    dataset_name, watermark_value, last_batch_id, rows_extracted, updated_at
)
SELECT dataset_name, watermark_value, NULL, 0, CURRENT_TIMESTAMP
FROM (
    VALUES
        ('customers', (SELECT MAX(updated_at) FROM source.customers)),
        ('products', (SELECT MAX(updated_at) FROM source.products)),
        ('sellers', (SELECT MAX(updated_at) FROM source.sellers)),
        ('orders', (SELECT MAX(updated_at) FROM source.orders)),
        ('order_items', (SELECT MAX(updated_at) FROM source.order_items)),
        ('payments', (SELECT MAX(updated_at) FROM source.payments))
) AS watermarks(dataset_name, watermark_value)
ON CONFLICT (dataset_name) DO UPDATE SET
    watermark_value = EXCLUDED.watermark_value,
    last_batch_id = NULL,
    rows_extracted = 0,
    updated_at = CURRENT_TIMESTAMP;

