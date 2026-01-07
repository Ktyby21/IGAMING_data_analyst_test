-- 11)Для каждого пользователя найти дату первого депозита и время до первого депозита (в днях от регистрации).

WITH first_dep_data AS(
    SELECT
        MIN(DATE(event_time)) as early_dep_date,
        user_id,
        event_type
    FROM events
    WHERE event_type = 'deposit'
    GROUP BY user_id, event_type)

SELECT 
    u.user_id,
    u.registration_date,
    f.early_dep_date - u.registration_date AS days_from_registration_to_dep
FROM users u
LEFT JOIN first_dep_data f
ON u.user_id = f.user_id
ORDER BY user_id;

-- 12) Конверсия в депозит: доля пользователей, сделавших депозит в первые 7 дней после регистрации (по источникам source).

WITH first_dep_data AS(
    SELECT
        MIN(DATE(event_time)) as early_dep_date,
        user_id,
        event_type
    FROM events
    WHERE event_type = 'deposit'
    GROUP BY user_id, event_type),

day_to_dep AS (
    SELECT 
        u.user_id,
        u.source,
        u.registration_date,
        f.early_dep_date - u.registration_date AS days_from_registration_to_dep
    FROM users u
    LEFT JOIN first_dep_data f
    ON u.user_id = f.user_id),

count_7_days_dep AS(
    SELECT
        source,
        COUNT(*) AS days_dep
    FROM day_to_dep
    WHERE days_from_registration_to_dep IS NOT NULL AND days_from_registration_to_dep < 7
    GROUP BY source
),

count_users AS (
    SELECT
        source,
        COUNT(*) as user_count
    FROM users
    GROUP BY source
)

SELECT
    u.source,
    u.user_count,
    sdd.days_dep,
    ROUND((1.0 * sdd.days_dep / u.user_count), 5) as conversion_7_days
FROM count_users u
LEFT JOIN count_7_days_dep sdd
ON u.source = sdd.source;

-- 13) Payer conversion по дням: доля DAU, которые сделали purchase в тот же день.

WITH count_purchase_users AS(
    SELECT
        COUNT(DISTINCT user_id) AS purchase_users,
        DATE(event_time) AS date_event
    FROM events
    WHERE event_type = 'purchase'
    GROUP BY date_event),

dau AS (
    SELECT 
        DATE(session_start) as converted_date,
        COUNT(DISTINCT user_id) AS count_dau
    FROM sessions
    GROUP BY converted_date)

SELECT d.converted_date,
    d.count_dau,
    p.purchase_users,
    ROUND((1.0 * COALESCE(p.purchase_users,0)/ d.count_dau), 5) AS Payer_conversion
FROM dau d
LEFT JOIN count_purchase_users p
ON d.converted_date = p.date_event
ORDER BY d.converted_date;

-- 14) ARPPU по месяцам (purchase amount / #платящих в месяц).

WITH month_amount AS(
    SELECT
        SUM(amount) AS purchase_amount,
        DATE_TRUNC('month', event_time)::date AS event_month
    FROM events
    WHERE event_type = 'purchase'
    GROUP BY event_month),

count_purchase_users AS(
    SELECT
        COUNT(DISTINCT user_id) AS purchase_users,
        DATE_TRUNC('month', event_time)::date AS event_month
    FROM events
    WHERE event_type = 'purchase'
    GROUP BY event_month)

SELECT
    a.event_month,
    u.purchase_users,
    a.purchase_amount,
    ROUND((1.0 * a.purchase_amount / u.purchase_users), 5) AS arppu
FROM month_amount a 
LEFT JOIN count_purchase_users u
ON a.event_month = u.event_month
ORDER BY a.event_month;

-- 15) ARPDAU по дням (purchase amount / DAU).

WITH dau AS (
    SELECT 
        DATE(session_start) as converted_date,
        COUNT(DISTINCT user_id) AS count_dau
    FROM sessions
    GROUP BY converted_date),

day_amount AS(
    SELECT
        SUM(amount) AS purchase_amount,
        DATE(event_time) AS date_event
    FROM events
    WHERE event_type = 'purchase'
    GROUP BY date_event)

SELECT 
    d.converted_date,
    a.purchase_amount,
    d.count_dau,
    ROUND((1.0 * a.purchase_amount / d.count_dau), 2) AS ARPDAU
FROM dau d
LEFT JOIN day_amount a
ON d.converted_date = a.date_event
ORDER BY a.date_event;

-- 16) Cohort retention: D1/D7/D30 по когорте регистрации (по registration_date).

WITH session_date AS(
    SELECT 
        user_id,
        DATE(session_start) as session_date
    FROM sessions
),
d_check AS
    (SELECT DISTINCT
        u.user_id,
        u.registration_date,
        d1.session_date AS d1_check,
        d7.session_date AS d7_check,
        d30.session_date AS d30_check
    FROM users u
    LEFT JOIN session_date d1
    ON u.user_id = d1.user_id AND (u.registration_date + 1) = d1.session_date
    LEFT JOIN session_date d7
    ON u.user_id = d7.user_id AND (u.registration_date + 7) = d7.session_date
    LEFT JOIN session_date d30
    ON u.user_id = d30.user_id AND (u.registration_date + 30) = d30.session_date
    ORDER BY user_id)

SELECT
    registration_date,
    ROUND((1.0 * COUNT(d1_check)/COUNT(user_id)), 2) as coh_ret_d1,
    ROUND((1.0 * COUNT(d7_check)/COUNT(user_id)), 2) as coh_ret_d7,
    ROUND((1.0 * COUNT(d30_check)/COUNT(user_id)), 2) as coh_ret_d30
FROM d_check
GROUP BY registration_date
ORDER BY registration_date;

-- 17) Сегментация по RFM-лайту:
-- Recency = дни с последней сессии
-- Frequency = число сессий за 30 дней
-- Monetary = сумма purchase за 30 дней

WITH last_day AS(
    SELECT 
        user_id,
        MAX(DATE(session_end)) AS last_day_session
    FROM sessions
    GROUP BY user_id),
user_last_activity AS(
    SELECT
        user_id,
        CURRENT_DATE - last_day_session AS days_from_last_activity
    FROM last_day),
frequency AS(
    SELECT
        user_id,
        COUNT(session_id) AS session_count_last_30d
    FROM sessions
    WHERE session_start >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY user_id),
monetary AS(
    SELECT
        SUM(amount) AS purchase_amount_last_30d,
        user_id
    FROM events
    WHERE event_type = 'purchase' AND
        event_time >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY user_id),
rfm AS(
    SELECT
        u.user_id,
        la.days_from_last_activity,
        f.session_count_last_30d,
        m.purchase_amount_last_30d
    FROM users u
    LEFT JOIN user_last_activity la
    ON u.user_id = la.user_id
    LEFT JOIN frequency f
    ON u.user_id = f.user_id
    LEFT JOIN monetary m
    ON u.user_id = m.user_id
    ORDER BY user_id ),
rfm_ntile AS(
    SELECT
        user_id,
        NTILE(5) OVER (ORDER BY days_from_last_activity DESC) AS r_score,
        NTILE(5) OVER (ORDER BY session_count_last_30d) AS f_score,
        NTILE(5) OVER (ORDER BY purchase_amount_last_30d) AS m_score
    FROM rfm
    ORDER BY user_id)

SELECT
    user_id,
    r_score, f_score, m_score,
    (r_score::text || f_score::text || m_score::text) AS rfm_score
FROM rfm_ntile;

-- 18) Воронка: registration -> first_session -> first_purchase (в процентах и медианное время между шагами).

WITH first_session AS (
    SELECT user_id,
        MIN(session_start) AS first_session
    FROM sessions
    GROUP BY user_id
    ORDER BY user_id),

first_purchase AS(
    SELECT
        user_id,
        MIN(event_time) AS first_purchase
    FROM events
    WHERE event_type = 'purchase'
    GROUP BY user_id),

user_with_dates AS(
    SELECT
        u.user_id,
        u.registration_date,
        EXTRACT(EPOCH FROM (fs.first_session - u.registration_date))/60 AS registration__first_session_minutes,
        fs.first_session,
        EXTRACT(EPOCH FROM (fp.first_purchase - fs.first_session))/60  AS first_session__first_purchase_minutes,
        fp.first_purchase
    FROM users u
    LEFT JOIN first_session fs
    ON u.user_id = fs.user_id
    LEFT JOIN first_purchase fp
    ON u.user_id = fp.user_id)

SELECT
    ROUND((percentile_cont(0.5) WITHIN GROUP (ORDER BY registration__first_session_minutes)
        FILTER (WHERE registration__first_session_minutes IS NOT NULL))::numeric, 2) AS median_registration__first_session_minutes,
    ROUND((100.00 * COUNT(first_session) / COUNT(registration_date)), 2) AS percent_from_registration_to_first_session,
    ROUND((percentile_cont(0.5) WITHIN GROUP (ORDER BY first_session__first_purchase_minutes)
        FILTER (WHERE first_session__first_purchase_minutes IS NOT NULL))::numeric, 2) AS median_first_session__first_purchase_minutes,
    ROUND((100.00 * COUNT(first_purchase) / COUNT(first_session)), 2) AS percent_from_first_session_to_first_purchase
FROM user_with_dates;

-- 19.	Rolling 7d: 7-дневный rolling sum sessions.revenue по дням (на уровне всей платформы).
WITH bounds AS(
    SELECT
        MAX(DATE(session_start)) AS max_date,
        MIN(DATE(session_start)) AS min_date
    FROM
        sessions),

dates AS (
    SELECT
        generate_series(bounds.min_date, bounds.max_date, INTERVAL '1 day')::date AS revenue_day
    FROM bounds
    ORDER BY revenue_day),

daily_revenue AS(
    SELECT
        SUM(revenue) AS revenue,
        session_start::date AS session_date
    FROM sessions
    GROUP BY session_start::date)

SELECT
    d.revenue_day,
    SUM(COALESCE(dr.revenue,0)) OVER (ORDER BY revenue_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
FROM dates d
LEFT JOIN daily_revenue dr
ON d.revenue_day = dr.session_date
ORDER BY d.revenue_day;

-- 20.	Rolling 7d по пользователю: 7-дневная сумма purchase amount по каждому user_id (оконка).
WITH bounds AS(
    SELECT
        user_id,
        MAX(event_time::date) AS max_date,
        MIN(event_time::date) AS min_date
    FROM events
    WHERE event_type = 'purchase'
    GROUP BY user_id),
dates AS(
    SELECT
        b.user_id,
        gs::date AS purchase_day
    FROM bounds b
    CROSS JOIN LATERAL generate_series(b.min_date,b.max_date,INTERVAL '1 day') AS gs),

user_amount AS(
    SELECT
        user_id,
        SUM(amount) AS amount,
        event_time::date AS event_date
    FROM events
    WHERE event_type = 'purchase'
    GROUP BY user_id, event_time::date),

user_amount_by_all_dates AS(
    SELECT
        d.user_id,
        d.purchase_day,
        COALESCE(ua.amount,0) AS amount
    FROM dates d
    LEFT JOIN user_amount ua
    ON d.user_id = ua.user_id AND d.purchase_day = ua.event_date
    ORDER BY d.purchase_day, d.user_id)

SELECT
    user_id,
    purchase_day,
    SUM(COALESCE(amount,0)) OVER (PARTITION BY user_id ORDER BY purchase_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
FROM user_amount_by_all_dates;