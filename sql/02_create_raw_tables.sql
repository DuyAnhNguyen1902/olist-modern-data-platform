-- Raw tables intentionally keep source fields as text. Casting and business rules belong
-- to staging so the original source representation remains auditable.

CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id                TEXT,
    customer_unique_id         TEXT,
    customer_zip_code_prefix   TEXT,
    customer_city              TEXT,
    customer_state             TEXT,
    source_file                TEXT,
    batch_id                   TEXT,
    loaded_at                  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id                         TEXT,
    customer_id                      TEXT,
    order_status                     TEXT,
    order_purchase_timestamp         TEXT,
    order_approved_at                TEXT,
    order_delivered_carrier_date     TEXT,
    order_delivered_customer_date    TEXT,
    order_estimated_delivery_date    TEXT,
    source_file                      TEXT,
    batch_id                         TEXT,
    loaded_at                        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id              TEXT,
    order_item_id         TEXT,
    product_id            TEXT,
    seller_id             TEXT,
    shipping_limit_date   TEXT,
    price                  TEXT,
    freight_value          TEXT,
    source_file            TEXT,
    batch_id               TEXT,
    loaded_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.payments (
    order_id               TEXT,
    payment_sequential     TEXT,
    payment_type           TEXT,
    payment_installments   TEXT,
    payment_value          TEXT,
    source_file            TEXT,
    batch_id               TEXT,
    loaded_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.reviews (
    review_id                 TEXT,
    order_id                  TEXT,
    review_score              TEXT,
    review_comment_title      TEXT,
    review_comment_message    TEXT,
    review_creation_date      TEXT,
    review_answer_timestamp   TEXT,
    source_file               TEXT,
    batch_id                  TEXT,
    loaded_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.products (
    product_id                   TEXT,
    product_category_name        TEXT,
    product_name_lenght          TEXT,
    product_description_lenght   TEXT,
    product_photos_qty           TEXT,
    product_weight_g             TEXT,
    product_length_cm            TEXT,
    product_height_cm            TEXT,
    product_width_cm             TEXT,
    source_file                  TEXT,
    batch_id                     TEXT,
    loaded_at                    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id                TEXT,
    seller_zip_code_prefix   TEXT,
    seller_city              TEXT,
    seller_state             TEXT,
    source_file              TEXT,
    batch_id                 TEXT,
    loaded_at                TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.geolocation (
    geolocation_zip_code_prefix   TEXT,
    geolocation_lat               TEXT,
    geolocation_lng               TEXT,
    geolocation_city              TEXT,
    geolocation_state             TEXT,
    source_file                   TEXT,
    batch_id                      TEXT,
    loaded_at                     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.category_translation (
    product_category_name           TEXT,
    product_category_name_english   TEXT,
    source_file                     TEXT,
    batch_id                        TEXT,
    loaded_at                       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Added separately so existing RAW tables created by earlier project versions are migrated.
ALTER TABLE raw.customers ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
ALTER TABLE raw.orders ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
ALTER TABLE raw.order_items ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
ALTER TABLE raw.payments ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
ALTER TABLE raw.reviews ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
ALTER TABLE raw.products ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
ALTER TABLE raw.sellers ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
ALTER TABLE raw.geolocation ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
ALTER TABLE raw.category_translation ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ;
