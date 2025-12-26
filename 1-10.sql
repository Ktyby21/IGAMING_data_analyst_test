-- 1) Сколько регистраций по дням? (daily new users)
SELECT 
    registration_date,
    COUNT(*)
FROM 
    users
GROUP BY 
    registration_date
ORDER BY
    registration_date DESC;

-- 2) Топ-10 стран по числу пользователей.
SELECT 
    country,
    COUNT(*) as count_user
FROM 
    users
GROUP BY 
    country
ORDER BY 
    count_user DESC
LIMIT 10;

-- 3) DAU по дням (по sessions, уникальные user_id в день).
SELECT 
    DATE(session_start) as converted_date,
    COUNT(DISTINCT user_id)
FROM
    sessions
GROUP BY converted_date
ORDER BY converted_date;

-- 4) MAU по месяцам.
SELECT
    DATE_TRUNC('month',session_start)::date AS session_month,
    COUNT(DISTINCT user_id)
FROM 
    sessions
GROUP BY
    session_month
ORDER BY
    session_month;

-- 5) DAU/MAU (stickiness) по месяцам.
WITH dau_by_day AS(
    SELECT 
        DATE(session_start) as converted_date,
        COUNT(DISTINCT user_id) as count_users
    FROM
        sessions
    GROUP BY converted_date),

avg_dau_per_month AS(
    SELECT
        ROUND((AVG(count_users)), 2) as avg_DAU_per_month,
        DATE_TRUNC('month',converted_date)::date AS session_month
    FROM
        dau_by_day
    GROUP BY session_month),

mau_by_month AS(
    SELECT
        DATE_TRUNC('month',session_start)::date AS session_month,
        COUNT(DISTINCT user_id) as MAU
    FROM 
        sessions
    GROUP BY
        session_month
)

SELECT 
    a.session_month,
    a.avg_DAU_per_month,
    n.MAU,
    ROUND((a.avg_DAU_per_month/n.MAU),5) AS DAU_MAU_stickiness
FROM
    avg_dau_per_month a
JOIN
    mau_by_month n
ON
    a.session_month = n.session_month;
    

-- 6) Средняя длительность сессии по игре (session_end - session_start).
SELECT 
    game_played,
    AVG(EXTRACT(EPOCH FROM(session_end - session_start))) / 60.0 as session_durability
FROM
    sessions
GROUP BY
    game_played
ORDER BY
    session_durability DESC;

-- 7) Топ-5 игр по суммарной sessions.revenue.
SELECT 
    game_played,
    SUM(revenue) as sum_revenue
FROM
    sessions
GROUP BY
    game_played
ORDER BY
    sum_revenue DESC
LIMIT 5;

-- 8) Сколько событий каждого типа по дням? (events.event_type)
SELECT 
    event_type,
    DATE(event_time) as event_date,
    COUNT(*) as count_event_type
FROM
    events
GROUP BY
    event_type,event_date
ORDER BY event_date,event_type;

-- 9) Сколько уникальных платящих пользователей (есть deposit или purchase) за весь период?
WITH sort_data AS
    (SELECT
        user_id,
        event_type
    FROM events
    WHERE event_type = 'purchase' OR event_type = 'deposit')

SELECT
    COUNT(DISTINCT user_id) as count
FROM sort_data;

-- 10) “Последние 7 дней”: найти пользователей, у кого SUM(purchase amount) за последние 7 дней > 100.
WITH date_max AS(
    SELECT 
        MAX(DATE(event_time)) as max_event_date
    FROM
        events
    ),

sort_data AS (
    SELECT 
        *
    FROM
        events
    WHERE
        event_time >= (SELECT max_event_date FROM date_max) - INTERVAL '7 days'
        AND event_type = 'purchase')

SELECT
    user_id,
    SUM(amount) AS sum_amount
FROM
    sort_data
GROUP BY
    user_id
HAVING SUM(amount) >= 100;
