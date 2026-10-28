-- ============================================================================
-- Capibara Analytics / Блок А, вопрос 1
-- Выручка и число заказов по месяцам, сентябрь 2016 – август 2018
-- ============================================================================
-- НАЗНАЧЕНИЕ
--   Помесячная динамика продаж: сколько заказов и какая выручка в каждом
--   месяце периода. Отчёт обязан содержать все 24 месяца периода, включая
--   месяцы без заказов (выручка = 0).
--
-- ОПРЕДЕЛЕНИЯ МЕТРИК
--   Популяция заказов: заказы со статусом 'delivered' — заказ считается
--   выручкой, когда товар вручён покупателю. Статусы 'canceled',
--   'unavailable', 'created', 'approved', 'processing', 'invoiced',
--   'shipped' выручкой не являются.
--   Выручка: SUM(price) по позициям заказа (уровень товарной позиции,
--   raw.order_items). Цена товара без стоимости доставки — это именно
--   «выручка от продажи товаров»; freight относится к логистике.
--   Месяц: date_trunc('month', order_purchase_timestamp) — момент
--   оформления заказа, а не оплаты или доставки.
--   Приведение типов: raw-слой хранит всё как text; цена кастуется
--   в numeric, даты — в timestamp.
--
-- ЗАЩИТА ОТ ОШИБОК
--   - Календарь месяцев генерируется через generate_series, заказы
--     присоединяются LEFT JOIN — месяц без заказов не теряется.
--   - Агрегация сначала по заказу-месяцу на уровне позиций, затем
--     сворачивание в месяц: строки не умножаются, заказы не дублируются.
--   - Сортировка по месяцу — детерминированная.
--
-- ОЖИДАЕМАЯ СТРУКТУРА РЕЗУЛЬТАТА
--   month (date, первый день месяца) | orders_count (bigint) | revenue (numeric)
--   Ровно 24 строки: 2016-09-01 ... 2018-08-01.
--
-- КОНТРОЛЬНЫЕ ПРОВЕРКИ (выполнены на исходных CSV)
--   1. COUNT(*) = 24 строки.
--   2. Ровно одна строка с revenue = 0 (2016-12 — заказов не было).
--   3. SUM(revenue) = 13 221 498.11.
--   4. SUM(orders_count) = 96 478 (все delivered-заказы попали в период;
--      заказов вне периода нет).
--
-- ВОЗМОЖНЫЕ РАСХОЖДЕНИЯ
--   - Добавление freight_value к выручке даёт 15 424 463.65 — это оборот
--     с доставкой, другая метрика.
--   - Включение недоставленных статусов завышает сумму.
--   - Отсутствие generate_series «съедает» декабрь 2016 → 23 строки.
-- ============================================================================

WITH calendar AS (
    SELECT generate_series(
               DATE '2016-09-01',
               DATE '2018-08-01',
               INTERVAL '1 month'
           )::date AS month
),
order_revenue AS (                       -- уровень: заказ
    SELECT o.order_id,
           date_trunc('month', o.order_purchase_timestamp::timestamp)::date AS month,
           SUM(oi.price::numeric) AS order_revenue
    FROM raw.orders o
    JOIN raw.order_items oi
      ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.order_purchase_timestamp
)
SELECT c.month,
       COUNT(orv.order_id)              AS orders_count,
       COALESCE(SUM(orv.order_revenue), 0) AS revenue
FROM calendar c
LEFT JOIN order_revenue orv
       ON orv.month = c.month
GROUP BY c.month
ORDER BY c.month;
