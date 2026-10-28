-- Q1. Revenue and order count by month, September 2016 through August 2018.
-- Revenue is the sum of delivered item prices, matching the case control total.

CREATE OR REPLACE VIEW mart.capibara_q1_monthly_revenue AS
WITH months AS (
    SELECT generate_series(
        DATE '2016-09-01',
        DATE '2018-08-01',
        INTERVAL '1 month'
    )::date AS month_start
),
order_stats AS (
    SELECT
        date_trunc('month', purchase_timestamp)::date AS month_start,
        count(*) AS orders_count
    FROM core.fact_orders
    WHERE status = 'delivered'
      AND purchase_timestamp >= TIMESTAMPTZ '2016-09-01 00:00:00+00'
      AND purchase_timestamp <  TIMESTAMPTZ '2018-09-01 00:00:00+00'
    GROUP BY 1
),
revenue_stats AS (
    SELECT
        date_trunc('month', o.purchase_timestamp)::date AS month_start,
        sum(oi.price) AS revenue
    FROM core.fact_order_items oi
    JOIN core.fact_orders o
      ON o.order_id = oi.order_id
    WHERE o.status = 'delivered'
      AND o.purchase_timestamp >= TIMESTAMPTZ '2016-09-01 00:00:00+00'
      AND o.purchase_timestamp <  TIMESTAMPTZ '2018-09-01 00:00:00+00'
    GROUP BY 1
)
SELECT
    to_char(m.month_start, 'YYYY-MM') AS month,
    COALESCE(os.orders_count, 0) AS orders_count,
    ROUND(COALESCE(rs.revenue, 0), 2) AS revenue
FROM months m
LEFT JOIN order_stats os
  ON os.month_start = m.month_start
LEFT JOIN revenue_stats rs
  ON rs.month_start = m.month_start
ORDER BY m.month_start;
