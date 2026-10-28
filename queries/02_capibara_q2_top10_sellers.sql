-- Q2. Top 10 sellers by delivered item-price revenue.

CREATE OR REPLACE VIEW mart.capibara_q2_top10_sellers AS
SELECT
    oi.seller_id,
    s.city,
    s.state,
    count(DISTINCT oi.order_id) AS orders_count,
    count(*) AS units_sold,
    ROUND(sum(oi.price), 2) AS revenue
FROM core.fact_order_items oi
JOIN core.fact_orders o
  ON o.order_id = oi.order_id
LEFT JOIN core.dim_sellers s
  ON s.seller_id = oi.seller_id
WHERE o.status = 'delivered'
GROUP BY
    oi.seller_id,
    s.city,
    s.state
ORDER BY revenue DESC, oi.seller_id
LIMIT 10;
