-- Q3. Average delivered order check, including item freight.
-- Each source row is one unit; therefore units per order equal order lines here.

CREATE OR REPLACE VIEW mart.capibara_q3_avg_order_value AS
WITH order_totals AS (
    SELECT
        o.order_id,
        count(*) AS lines_count,
        count(*) AS units_count,
        sum(oi.price + oi.freight_value) AS order_check
    FROM core.fact_order_items oi
    JOIN core.fact_orders o
      ON o.order_id = oi.order_id
    WHERE o.status = 'delivered'
    GROUP BY o.order_id
)
SELECT
    ROUND(avg(order_check), 2) AS avg_order_value,
    ROUND(avg(lines_count), 2) AS avg_lines_per_order,
    ROUND(avg(units_count), 2) AS avg_units_per_order
FROM order_totals;
