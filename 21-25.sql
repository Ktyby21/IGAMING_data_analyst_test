-- 21.	Найти “анома́льные дни” по revenue: дни, где revenue выше среднего на 3σ (можно через daily агрегат + z-score).
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

WITH percent_all AS (
    SELECT
        u.source,
        u.device,
        SUM(s.revenue) AS revenue,
        ROUND((100.00 * SUM(s.revenue)/(SUM(SUM(s.revenue)) OVER ())), 2) AS percent_all_revenue
    FROM sessions s
    LEFT JOIN users u
    ON s.user_id = u.user_id
    GROUP BY u.source,u.device),
percent_month AS (
    SELECT
        u.source,
        u.device,
        DATE_TRUNC('month', s.session_start)::date AS session_month,
        SUM(s.revenue) AS revenue,
        ROUND((100.00 * SUM(s.revenue)/(SUM(SUM(s.revenue)) OVER (PARTITION BY (DATE_TRUNC('month', s.session_start)::date)))), 2) AS percent_revenue_by_month
    FROM sessions s
    LEFT JOIN users u
    ON s.user_id = u.user_id
    GROUP BY u.source,u.device,session_month)

SELECT
    pm.source,
    pm.device,
    pm.session_month,
    pm.revenue,
    pm.percent_revenue_by_month,
    pa.percent_all_revenue
FROM percent_month pm
LEFT JOIN percent_all pa 
ON pm.source = pa.source AND pm.device = pa.device
ORDER BY pm.source,pm.device,pm.session_month;

-- 23.	LTV-30 (упрощённо): сумма purchase amount за первые 30 дней после регистрации по когортам.
WITH daily_amount AS (
    SELECT
        e.user_id,
        SUM(e.amount) AS daily_amount,
        e.event_time::date as date,
        u.registration_date
    FROM events e
    LEFT JOIN users u
    ON e.user_id = u.user_id
    WHERE e.event_type = 'purchase'
    GROUP BY e.user_id,e.event_time::date,u.registration_date),
filtering_date AS (
    SELECT
        user_id,
        daily_amount,
        date,
        registration_date
    FROM daily_amount
    WHERE registration_date + 30 > date)

SELECT
    registration_date,
    SUM(daily_amount) AS daily_amount,
    COUNT(DISTINCT user_id) AS count_users,
    ROUND((1.00 * SUM(daily_amount) / COUNT(DISTINCT user_id)),2) AS ltv_30
FROM filtering_date
GROUP BY registration_date
ORDER BY registration_date

-- 24.	“Кто отвалился”: пользователи с 0 сессий за последние 14 дней, но были активны раньше (верни список + их last_session_date).
WITH 
last_users_session AS (
    SELECT
        MAX(session_start::date) AS last_session,
        user_id
    FROM sessions
    GROUP BY user_id)

SELECT
    user_id,
    last_session
FROM last_users_session
WHERE last_session + INTERVAL '14 days' < (
    SELECT
        MAX(DATE(session_start)) AS max_date
    FROM
        sessions)
ORDER BY user_id
-- 25.	Оптимизация: взять любой тяжёлый запрос (например DAU/Retention) и прикинуть, какие индексы нужны и почему (по колонкам WHERE/JOIN/ORDER).