-- Capibara core model: typed views over the immutable raw layer.
-- Views are idempotent and preserve rows; business filters belong to marts.

CREATE OR REPLACE VIEW core.dim_customers AS
SELECT
    customer_unique_id,
    MIN(customer_zip_code_prefix) AS zip_code_prefix,
    MIN(customer_city) AS city,
    MIN(customer_state) AS state
FROM raw.customers
GROUP BY customer_unique_id;

CREATE OR REPLACE VIEW core.dim_sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix AS zip_code_prefix,
    seller_city AS city,
    seller_state AS state
FROM raw.sellers;

CREATE OR REPLACE VIEW core.dim_products AS
SELECT
    p.product_id,
    NULLIF(p.product_category_name, '') AS category_name,
    t.product_category_name_english AS category_name_en,
    NULLIF(p.product_weight_g, '')::numeric AS weight_g,
    NULLIF(p.product_length_cm, '')::numeric AS length_cm,
    NULLIF(p.product_height_cm, '')::numeric AS height_cm,
    NULLIF(p.product_width_cm, '')::numeric AS width_cm
FROM raw.products p
LEFT JOIN raw.product_category_translation t
    ON t.product_category_name = p.product_category_name;

CREATE OR REPLACE VIEW core.fact_orders AS
SELECT
    o.order_id,
    c.customer_unique_id,
    o.order_status AS status,
    NULLIF(o.order_purchase_timestamp, '')::timestamptz AS purchase_timestamp,
    NULLIF(o.order_approved_at, '')::timestamptz AS approved_at,
    NULLIF(o.order_delivered_carrier_date, '')::timestamptz AS delivered_carrier_at,
    NULLIF(o.order_delivered_customer_date, '')::timestamptz AS delivered_customer_at,
    NULLIF(o.order_estimated_delivery_date, '')::timestamptz AS estimated_delivery_at
FROM raw.orders o
JOIN raw.customers c
    ON c.customer_id = o.customer_id;

CREATE OR REPLACE VIEW core.fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id::integer AS item_number,
    oi.product_id,
    oi.seller_id,
    NULLIF(oi.shipping_limit_date, '')::timestamptz AS shipping_limit_at,
    NULLIF(oi.price, '')::numeric AS price,
    NULLIF(oi.freight_value, '')::numeric AS freight_value
FROM raw.order_items oi;

CREATE OR REPLACE VIEW core.fact_payments AS
SELECT
    op.order_id,
    op.payment_sequential::integer AS payment_sequence,
    op.payment_type,
    NULLIF(op.payment_installments, '')::integer AS installments,
    NULLIF(op.payment_value, '')::numeric AS payment_value
FROM raw.order_payments op;

CREATE OR REPLACE VIEW core.fact_reviews AS
SELECT
    review_id,
    order_id,
    NULLIF(review_score, '')::smallint AS review_score,
    review_comment_title,
    review_comment_message,
    NULLIF(review_creation_date, '')::timestamptz AS created_at,
    NULLIF(review_answer_timestamp, '')::timestamptz AS answered_at
FROM raw.order_reviews;
