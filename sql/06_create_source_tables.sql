CREATE TABLE IF NOT EXISTS source.customers (
    customer_id                TEXT PRIMARY KEY,
    customer_unique_id         TEXT NOT NULL,
    customer_zip_code_prefix   INTEGER,
    customer_city              TEXT,
    customer_state             TEXT,
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS source.products (
    product_id                   TEXT PRIMARY KEY,
    product_category_name        TEXT,
    product_name_lenght          INTEGER,
    product_description_lenght   INTEGER,
    product_photos_qty           INTEGER,
    product_weight_g             NUMERIC(12, 2),
    product_length_cm            NUMERIC(12, 2),
    product_height_cm            NUMERIC(12, 2),
    product_width_cm             NUMERIC(12, 2),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS source.sellers (
    seller_id                TEXT PRIMARY KEY,
    seller_zip_code_prefix   INTEGER,
    seller_city              TEXT,
    seller_state             TEXT,
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS source.orders (
    order_id                         TEXT PRIMARY KEY,
    customer_id                      TEXT NOT NULL REFERENCES source.customers(customer_id),
    order_status                     TEXT NOT NULL,
    order_purchase_timestamp         TIMESTAMP NOT NULL,
    order_approved_at                TIMESTAMP,
    order_delivered_carrier_date     TIMESTAMP,
    order_delivered_customer_date    TIMESTAMP,
    order_estimated_delivery_date    TIMESTAMP,
    updated_at                       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS source.order_items (
    order_id              TEXT NOT NULL REFERENCES source.orders(order_id),
    order_item_id         INTEGER NOT NULL,
    product_id            TEXT NOT NULL REFERENCES source.products(product_id),
    seller_id             TEXT NOT NULL REFERENCES source.sellers(seller_id),
    shipping_limit_date   TIMESTAMP,
    price                 NUMERIC(12, 2) NOT NULL,
    freight_value         NUMERIC(12, 2) NOT NULL,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE IF NOT EXISTS source.payments (
    order_id               TEXT NOT NULL REFERENCES source.orders(order_id),
    payment_sequential     INTEGER NOT NULL,
    payment_type           TEXT NOT NULL,
    payment_installments   INTEGER,
    payment_value          NUMERIC(12, 2) NOT NULL,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, payment_sequential)
);

