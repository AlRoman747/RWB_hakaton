-- Q4. Unique customers and customers with at least two orders.

CREATE OR REPLACE VIEW mart.capibara_q4_repeat_customers AS
WITH customer_orders AS (
    SELECT
        o.customer_unique_id,
        count(DISTINCT o.order_id) AS orders_count
    FROM core.fact_orders o
    GROUP BY o.customer_unique_id
)
SELECT
    count(*) AS total_customers,
    count(*) FILTER (WHERE orders_count >= 2) AS repeat_customers,
    ROUND(
        100.0 * count(*) FILTER (WHERE orders_count >= 2) / count(*),
        2
    ) AS repeat_share_pct
FROM customer_orders;
