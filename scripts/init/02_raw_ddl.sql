-- Raw source tables intentionally use text for every source column.
-- Type casting, deduplication and business keys belong to the core layer.

CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id text,
    customer_unique_id text,
    customer_zip_code_prefix text,
    customer_city text,
    customer_state text
);

CREATE TABLE IF NOT EXISTS raw.geolocation (
    geolocation_zip_code_prefix text,
    geolocation_lat text,
    geolocation_lng text,
    geolocation_city text,
    geolocation_state text
);

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id text,
    order_item_id text,
    product_id text,
    seller_id text,
    shipping_limit_date text,
    price text,
    freight_value text
);

CREATE TABLE IF NOT EXISTS raw.order_payments (
    order_id text,
    payment_sequential text,
    payment_type text,
    payment_installments text,
    payment_value text
);

CREATE TABLE IF NOT EXISTS raw.order_reviews (
    review_id text,
    order_id text,
    review_score text,
    review_comment_title text,
    review_comment_message text,
    review_creation_date text,
    review_answer_timestamp text
);

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id text,
    customer_id text,
    order_status text,
    order_purchase_timestamp text,
    order_approved_at text,
    order_delivered_carrier_date text,
    order_delivered_customer_date text,
    order_estimated_delivery_date text
);

CREATE TABLE IF NOT EXISTS raw.products (
    product_id text,
    product_category_name text,
    product_name_lenght text,
    product_description_lenght text,
    product_photos_qty text,
    product_weight_g text,
    product_length_cm text,
    product_height_cm text,
    product_width_cm text
);

CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id text,
    seller_zip_code_prefix text,
    seller_city text,
    seller_state text
);

CREATE TABLE IF NOT EXISTS raw.product_category_translation (
    product_category_name text,
    product_category_name_english text
);

-- Metadata is committed only after all nine files pass validation.
CREATE TABLE IF NOT EXISTS raw.load_manifest (
    file_name text PRIMARY KEY,
    table_name text NOT NULL,
    run_id uuid NOT NULL,
    file_sha256 character(64) NOT NULL,
    source_rows bigint NOT NULL,
    loaded_rows bigint NOT NULL,
    loaded_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.load_state (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    run_id uuid NOT NULL,
    status text NOT NULL CHECK (status = 'success'),
    completed_at timestamp with time zone NOT NULL DEFAULT now()
);
