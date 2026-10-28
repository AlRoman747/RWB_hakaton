-- ============================================================================
-- Capibara Analytics / Блок А, вопрос 2
-- Топ-10 продавцов по выручке
-- ============================================================================
-- НАЗНАЧЕНИЕ
--   Рейтинг продавцов по выручке с атрибутами (город, штат), глубиной
--   (число заказов) и объёмом (единиц товара).
--
-- ОПРЕДЕЛЕНИЯ МЕТРИК
--   Популяция заказов: 'delivered' (та же семантика выручки, что в Q1).
--   Выручка продавца: SUM(price) только по ЕГО позициям
--   (raw.order_items.seller_id). Заказ с товарами нескольких продавцов
--   распределяется между ними по позициям — сумма заказа целиком
--   никому не приписывается.
--   orders_count: COUNT(DISTINCT order_id) — один заказ с двумя позициями
--   продавца считается один раз.
--   units_count: COUNT(*) по строкам позиций — строка order_items это
--   одна единица товара (в данных количества нет, одна строка = 1 шт.).
--   Атрибуты (город, штат) берутся из raw.sellers — справочник 1:1
--   к seller_id, поэтому JOIN не умножает строки.
--
-- ЗАЩИТА ОТ ОШИБОК
--   - JOIN orders сначала фильтрует популяцию, агрегация идёт по позициям
--     продавца — заказ не размножается по продавцам в сумме.
--   - Детерминированная сортировка: revenue DESC, затем seller_id ASC
--     как tie-breaker при равной выручке.
--
-- ОЖИДАЕМАЯ СТРУКТУРА РЕЗУЛЬТАТА
--   seller_id (text) | seller_city (text) | seller_state (text)
--   | orders_count (bigint) | units_count (bigint) | revenue (numeric)
--   Ровно 10 строк.
--
-- КОНТРОЛЬНЫЕ ПРОВЕРКИ (выполнены на исходных CSV)
--   1. Выручка первого продавца = 226 987.93
--      (seller_id = 4869f7a5dfa277a7dca6462dcf3b52b2).
--   2. Ровно 10 строк.
--   3. SUM(revenue) по топ-10 <= общей выручки 13 221 498.11.
--
-- ВОЗМОЖНЫЕ РАСХОЖДЕНИЯ
--   - Приписывание продавцу всей суммы заказа (включая чужие позиции)
--     завышает выручку.
--   - COUNT(order_id) вместо COUNT(DISTINCT order_id) завышает число
--     заказов у мультипозиционных продавцов.
-- ============================================================================

SELECT oi.seller_id,
       s.seller_city,
       s.seller_state,
       COUNT(DISTINCT oi.order_id) AS orders_count,
       COUNT(*)                    AS units_count,
       SUM(oi.price::numeric)      AS revenue
FROM raw.order_items oi
JOIN raw.orders o
  ON o.order_id = oi.order_id
 AND o.order_status = 'delivered'
JOIN raw.sellers s
  ON s.seller_id = oi.seller_id
GROUP BY oi.seller_id, s.seller_city, s.seller_state
ORDER BY revenue DESC, oi.seller_id ASC
LIMIT 10;
