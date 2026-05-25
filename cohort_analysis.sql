WITH users_parsed AS (
    SELECT
        u.user_id,
        u.promo_signup_flag,
        CASE
            WHEN REGEXP_REPLACE(split_part(trim(u.signup_datetime), ' ', 1), '[./]', '-', 'g')
                 ~ '^\d{1,2}-\d{1,2}-\d{4}$'
            THEN TO_DATE(
                REGEXP_REPLACE(split_part(trim(u.signup_datetime), ' ', 1), '[./]', '-', 'g'),
                'DD-MM-YYYY'
            )
            WHEN REGEXP_REPLACE(split_part(trim(u.signup_datetime), ' ', 1), '[./]', '-', 'g')
                 ~ '^\d{1,2}-\d{1,2}-\d{2}$'
            THEN TO_DATE(
                REGEXP_REPLACE(split_part(trim(u.signup_datetime), ' ', 1), '[./]', '-', 'g'),
                'DD-MM-YY'
            )
        END AS signup_ts
    FROM cohort_users_raw u
),

events_parsed AS (
    SELECT
        e.user_id,
        e.event_type,
        e.revenue,
        CASE
            WHEN e.event_datetime IS NOT NULL THEN
                CASE
                    WHEN REGEXP_REPLACE(split_part(trim(e.event_datetime), ' ', 1), '[./]', '-', 'g')
                         ~ '^\d{1,2}-\d{1,2}-\d{4}$'
                    THEN TO_DATE(
                        REGEXP_REPLACE(split_part(trim(e.event_datetime), ' ', 1), '[./]', '-', 'g'),
                        'DD-MM-YYYY'
                    )
                    WHEN REGEXP_REPLACE(split_part(trim(e.event_datetime), ' ', 1), '[./]', '-', 'g')
                         ~ '^\d{1,2}-\d{1,2}-\d{2}$'
                    THEN TO_DATE(
                        REGEXP_REPLACE(split_part(trim(e.event_datetime), ' ', 1), '[./]', '-', 'g'),
                        'DD-MM-YY'
                    )
                END
        END AS event_ts
    FROM cohort_events_raw e
    WHERE e.event_type IS NOT NULL
      AND e.event_type != 'test_event'
),

user_activity AS (
    SELECT
        u.user_id,
        u.promo_signup_flag,
        DATE_TRUNC('month', u.signup_ts)::date AS cohort_month,
        DATE_TRUNC('month', e.event_ts)::date  AS activity_month,
        e.event_type,
        (
            (EXTRACT(YEAR  FROM e.event_ts) - EXTRACT(YEAR  FROM u.signup_ts)) * 12
          + (EXTRACT(MONTH FROM e.event_ts) - EXTRACT(MONTH FROM u.signup_ts))
        )::int AS month_offset
    FROM users_parsed u
    JOIN events_parsed e ON u.user_id = e.user_id
    WHERE u.signup_ts IS NOT NULL
      AND e.event_ts  IS NOT NULL
)

SELECT
    promo_signup_flag,
    cohort_month,
    month_offset,
    COUNT(DISTINCT user_id) AS users_total
FROM user_activity
WHERE activity_month BETWEEN '2025-01-01' AND '2025-06-30'
GROUP BY
    promo_signup_flag,
    cohort_month,
    month_offset
ORDER BY
    promo_signup_flag,
    cohort_month,
    month_offset;