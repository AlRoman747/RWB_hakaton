\set ON_ERROR_STOP on

DROP TABLE IF EXISTS pg_temp.answer_checks;

CREATE TEMP TABLE answer_checks (
    question    text,
    check_name  text,
    expected    text,
    actual      text,
    passed      boolean
);

WITH stats AS (
    SELECT
        count(*) AS months,
        sum(orders_count) AS orders_count,
        round(sum(revenue), 2) AS total_revenue,
        count(*) FILTER (WHERE revenue = 0) AS zero_revenue_months
    FROM mart.capibara_q1_monthly_revenue
)
INSERT INTO answer_checks
SELECT 'q1', 'months', '24', months::text, months = 24 FROM stats
UNION ALL
SELECT 'q1', 'orders_count', '96478', orders_count::text,
       orders_count = 96478 FROM stats
UNION ALL
SELECT 'q1', 'total_revenue', '13221498.11', total_revenue::text,
       total_revenue = 13221498.11 FROM stats
UNION ALL
SELECT 'q1', 'zero_revenue_months', '1', zero_revenue_months::text,
       zero_revenue_months = 1 FROM stats;

WITH stats AS (
    SELECT
        count(*) AS sellers_count,
        max(revenue) AS top_revenue
    FROM mart.capibara_q2_top10_sellers
)
INSERT INTO answer_checks
SELECT 'q2', 'sellers_count', '10', sellers_count::text,
       sellers_count = 10 FROM stats
UNION ALL
SELECT 'q2', 'top_seller_revenue', '226987.93',
       round(top_revenue, 2)::text,
       round(top_revenue, 2) = 226987.93 FROM stats;

INSERT INTO answer_checks
SELECT 'q3', 'avg_order_value', '159.88', avg_order_value::text,
       avg_order_value = 159.88
FROM mart.capibara_q3_avg_order_value
UNION ALL
SELECT 'q3', 'avg_lines_per_order', '1.14', avg_lines_per_order::text,
       avg_lines_per_order = 1.14
FROM mart.capibara_q3_avg_order_value
UNION ALL
SELECT 'q3', 'avg_units_per_order', '1.14', avg_units_per_order::text,
       avg_units_per_order = 1.14
FROM mart.capibara_q3_avg_order_value;

INSERT INTO answer_checks
SELECT 'q4', 'total_customers', '96096', total_customers::text,
       total_customers = 96096
FROM mart.capibara_q4_repeat_customers
UNION ALL
SELECT 'q4', 'repeat_customers', '2997', repeat_customers::text,
       repeat_customers = 2997
FROM mart.capibara_q4_repeat_customers
UNION ALL
SELECT 'q4', 'repeat_share_pct', '3.12', repeat_share_pct::text,
       repeat_share_pct = 3.12
FROM mart.capibara_q4_repeat_customers;

WITH stats AS (
    SELECT
        count(*) AS categories_count,
        round(max(revenue), 2) AS top_revenue,
        round(sum(revenue), 2) AS total_revenue
    FROM mart.capibara_q5_category_revenue
)
INSERT INTO answer_checks
SELECT 'q5', 'categories_count', '74', categories_count::text,
       categories_count = 74 FROM stats
UNION ALL
SELECT 'q5', 'top_category_revenue', '1233131.72', top_revenue::text,
       top_revenue = 1233131.72 FROM stats
UNION ALL
SELECT 'q5', 'total_revenue', '13221498.11', total_revenue::text,
       total_revenue = 13221498.11 FROM stats;

DO $$
DECLARE
    failures integer;
BEGIN
    SELECT count(*) INTO failures
    FROM answer_checks
    WHERE NOT passed;

    IF failures > 0 THEN
        RAISE EXCEPTION '% answer checks failed. See answer_checks for details.', failures;
    END IF;

    RAISE NOTICE 'All 15 answer checks passed.';
END $$;

SELECT
    question,
    check_name,
    expected,
    actual,
    CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS result
FROM answer_checks
ORDER BY question, check_name;
