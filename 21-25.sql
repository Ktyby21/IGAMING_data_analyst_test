-- -- 21.	Найти “анома́льные дни” по revenue: дни, где revenue выше среднего на 3σ (можно через daily агрегат + z-score).
WITH daily_revenue AS(
    SELECT
        session_start::date AS date,
        SUM(revenue) AS daily_revenue
    FROM
        sessions
    GROUP BY
        session_start::date),

avg_sigma AS(
    SELECT
        AVG(daily_revenue) AS avg_revenue,
        STDDEV_POP(daily_revenue) AS sigma
    FROM daily_revenue)

SELECT
    dr.date,
    dr.daily_revenue,
    a.avg_revenue,
    a.sigma,
    (dr.daily_revenue - a.avg_revenue) / NULLIF(a.sigma, 0) AS z_score
FROM daily_revenue dr
CROSS JOIN avg_sigma a
WHERE ABS((dr.daily_revenue - a.avg_revenue) / NULLIF(a.sigma, 0)) >= 3;

-- 22.	Разложить revenue по источникам (source) и устройствам (device) — вклад в общий revenue и динамика.
-- 23.	LTV-30 (упрощённо): сумма purchase amount за первые 30 дней после регистрации по когортам.
-- 24.	“Кто отвалился”: пользователи с 0 сессий за последние 14 дней, но были активны раньше (верни список + их last_session_date).
-- 25.	Оптимизация: взять любой тяжёлый запрос (например DAU/Retention) и прикинуть, какие индексы нужны и почему (по колонкам WHERE/JOIN/ORDER).