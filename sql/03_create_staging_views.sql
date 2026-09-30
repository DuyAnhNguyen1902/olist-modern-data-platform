CREATE OR REPLACE VIEW staging.stg_customers AS
WITH ranked AS (
    SELECT
        customers.*,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY source_updated_at DESC NULLS LAST, loaded_at DESC
        ) AS row_number
    FROM raw.customers
)
SELECT
    TRIM(customer_id) AS customer_id,
    TRIM(customer_unique_id) AS customer_unique_id,
    NULLIF(customer_zip_code_prefix, '')::INTEGER AS customer_zip_code_prefix,
    NULLIF(TRIM(customer_city), '') AS customer_city,
    NULLIF(TRIM(customer_state), '') AS customer_state,
    batch_id,
    loaded_at
FROM ranked
WHERE row_number = 1;

CREATE OR REPLACE VIEW staging.stg_orders AS
WITH ranked AS (
    SELECT
        orders.*,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY source_updated_at DESC NULLS LAST, loaded_at DESC
        ) AS row_number
    FROM raw.orders
)
SELECT
    TRIM(order_id) AS order_id,
    TRIM(customer_id) AS customer_id,
    LOWER(TRIM(order_status)) AS order_status,
    NULLIF(order_purchase_timestamp, '')::TIMESTAMP AS order_purchase_timestamp,
    NULLIF(order_approved_at, '')::TIMESTAMP AS order_approved_at,
    NULLIF(order_delivered_carrier_date, '')::TIMESTAMP AS order_delivered_carrier_date,
    NULLIF(order_delivered_customer_date, '')::TIMESTAMP AS order_delivered_customer_date,
    NULLIF(order_estimated_delivery_date, '')::TIMESTAMP AS order_estimated_delivery_date,
    batch_id,
    loaded_at
FROM ranked
WHERE row_number = 1;

CREATE OR REPLACE VIEW staging.stg_order_items AS
WITH ranked AS (
    SELECT
        order_items.*,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, order_item_id
            ORDER BY source_updated_at DESC NULLS LAST, loaded_at DESC
        ) AS row_number
    FROM raw.order_items
)
SELECT
    TRIM(order_id) AS order_id,
    NULLIF(order_item_id, '')::INTEGER AS order_item_id,
    TRIM(product_id) AS product_id,
    TRIM(seller_id) AS seller_id,
    NULLIF(shipping_limit_date, '')::TIMESTAMP AS shipping_limit_date,
    NULLIF(price, '')::NUMERIC(12, 2) AS price,
    NULLIF(freight_value, '')::NUMERIC(12, 2) AS freight_value,
    batch_id,
    loaded_at
FROM ranked
WHERE row_number = 1;

CREATE OR REPLACE VIEW staging.stg_payments AS
WITH ranked AS (
    SELECT
        payments.*,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, payment_sequential
            ORDER BY source_updated_at DESC NULLS LAST, loaded_at DESC
        ) AS row_number
    FROM raw.payments
)
SELECT
    TRIM(order_id) AS order_id,
    NULLIF(payment_sequential, '')::INTEGER AS payment_sequential,
    LOWER(TRIM(payment_type)) AS payment_type,
    NULLIF(payment_installments, '')::INTEGER AS payment_installments,
    NULLIF(payment_value, '')::NUMERIC(12, 2) AS payment_value,
    batch_id,
    loaded_at
FROM ranked
WHERE row_number = 1;

CREATE OR REPLACE VIEW staging.stg_reviews AS
SELECT
    TRIM(review_id) AS review_id,
    TRIM(order_id) AS order_id,
    NULLIF(review_score, '')::SMALLINT AS review_score,
    NULLIF(TRIM(review_comment_title), '') AS review_comment_title,
    NULLIF(TRIM(review_comment_message), '') AS review_comment_message,
    NULLIF(review_creation_date, '')::TIMESTAMP AS review_creation_date,
    NULLIF(review_answer_timestamp, '')::TIMESTAMP AS review_answer_timestamp,
    batch_id,
    loaded_at
FROM raw.reviews;

CREATE OR REPLACE VIEW staging.stg_products AS
WITH ranked AS (
    SELECT
        products.*,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY source_updated_at DESC NULLS LAST, loaded_at DESC
        ) AS row_number
    FROM raw.products
)
SELECT
    TRIM(product_id) AS product_id,
    NULLIF(TRIM(product_category_name), '') AS product_category_name,
    NULLIF(product_name_lenght, '')::INTEGER AS product_name_length,
    NULLIF(product_description_lenght, '')::INTEGER AS product_description_length,
    NULLIF(product_photos_qty, '')::INTEGER AS product_photos_quantity,
    NULLIF(product_weight_g, '')::NUMERIC(12, 2) AS product_weight_g,
    NULLIF(product_length_cm, '')::NUMERIC(12, 2) AS product_length_cm,
    NULLIF(product_height_cm, '')::NUMERIC(12, 2) AS product_height_cm,
    NULLIF(product_width_cm, '')::NUMERIC(12, 2) AS product_width_cm,
    batch_id,
    loaded_at
FROM ranked
WHERE row_number = 1;

CREATE OR REPLACE VIEW staging.stg_sellers AS
WITH ranked AS (
    SELECT
        sellers.*,
        ROW_NUMBER() OVER (
            PARTITION BY seller_id
            ORDER BY source_updated_at DESC NULLS LAST, loaded_at DESC
        ) AS row_number
    FROM raw.sellers
)
SELECT
    TRIM(seller_id) AS seller_id,
    NULLIF(seller_zip_code_prefix, '')::INTEGER AS seller_zip_code_prefix,
    NULLIF(TRIM(seller_city), '') AS seller_city,
    NULLIF(TRIM(seller_state), '') AS seller_state,
    batch_id,
    loaded_at
FROM ranked
WHERE row_number = 1;

CREATE OR REPLACE VIEW staging.stg_category_translation AS
SELECT
    TRIM(product_category_name) AS product_category_name,
    TRIM(product_category_name_english) AS product_category_name_english,
    batch_id,
    loaded_at
FROM raw.category_translation;

-- One representative coordinate per ZIP prefix. Raw geolocation legitimately contains
-- multiple points for the same prefix, so it is aggregated rather than deduplicated blindly.
CREATE OR REPLACE VIEW staging.stg_geolocation AS
SELECT
    NULLIF(geolocation_zip_code_prefix, '')::INTEGER AS geolocation_zip_code_prefix,
    AVG(NULLIF(geolocation_lat, '')::DOUBLE PRECISION) AS latitude,
    AVG(NULLIF(geolocation_lng, '')::DOUBLE PRECISION) AS longitude,
    MIN(NULLIF(TRIM(geolocation_city), '')) AS city,
    MIN(NULLIF(TRIM(geolocation_state), '')) AS state
FROM raw.geolocation
GROUP BY NULLIF(geolocation_zip_code_prefix, '')::INTEGER;
