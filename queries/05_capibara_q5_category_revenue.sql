-- Q5. Delivered item-price revenue and revenue share by product category.
-- Prefer the English translation; retain Portuguese names missing from the
-- translation file. Only a genuinely empty source category becomes 'unknown'.

CREATE OR REPLACE VIEW mart.capibara_q5_category_revenue AS
SELECT
    COALESCE(p.category_name_en, p.category_name, 'unknown') AS category,
    ROUND(sum(oi.price), 2) AS revenue,
    ROUND(
        100.0 * sum(oi.price) / sum(sum(oi.price)) OVER (),
        2
    ) AS revenue_share_pct
FROM core.fact_order_items oi
JOIN core.fact_orders o
  ON o.order_id = oi.order_id
LEFT JOIN core.dim_products p
  ON p.product_id = oi.product_id
WHERE o.status = 'delivered'
GROUP BY COALESCE(p.category_name_en, p.category_name, 'unknown')
ORDER BY revenue DESC, category;
