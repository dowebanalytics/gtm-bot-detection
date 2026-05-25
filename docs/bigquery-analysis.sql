-- ============================================================================
-- BOT DETECTION — BigQuery Analysis Queries
-- Schema: GA4 export (events_* tables)
-- Custom dimensions: bot_status | bot_score | bot_signal
-- DO Web Analytics / Tag Manager Italia
-- ============================================================================
-- Sostituisci `your_project.your_dataset` con il tuo progetto e dataset GA4.
-- Sostituisci `events_*` con `events_YYYYMMDD` per analisi su una data specifica.
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 0. CTE BASE (riutilizzata in tutte le query)
--    Estrare bot_status, bot_score e bot_signal da ogni evento
-- ─────────────────────────────────────────────────────────────────────────────
-- Incolla questa CTE in cima alle query che vuoi comporre:
/*
WITH base AS (
  SELECT
    event_date,
    event_name,
    user_pseudo_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location')    AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_title')       AS page_title,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id')       AS session_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status')       AS bot_status,
    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'bot_score'),
      (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
    )                                                                                     AS bot_score,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_signal')       AS bot_signal,
    device.category        AS device_category,
    device.operating_system AS os,
    device.browser         AS browser,
    geo.country            AS country,
    geo.city               AS city
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
    AND bot_status IS NOT NULL  -- solo eventi con bot detection attiva
)
*/


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. KPI OVERVIEW — traffico umano vs bot
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') AS bot_status,
    user_pseudo_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id') AS session_id
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
)
SELECT
  COALESCE(bot_status, 'unknown')         AS bot_status,
  COUNT(*)                                AS total_events,
  COUNT(DISTINCT user_pseudo_id)          AS unique_users,
  COUNT(DISTINCT session_id)              AS unique_sessions,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_events
FROM base
GROUP BY 1
ORDER BY total_events DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. TREND GIORNALIERO — bot vs umani nel tempo
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    event_date,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') AS bot_status,
    user_pseudo_id
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
)
SELECT
  event_date,
  COUNTIF(bot_status = 'possible_bot')                                             AS bot_events,
  COUNTIF(bot_status = 'normal_user')                                              AS human_events,
  COUNT(DISTINCT IF(bot_status = 'possible_bot', user_pseudo_id, NULL))            AS bot_users,
  COUNT(DISTINCT IF(bot_status = 'normal_user',  user_pseudo_id, NULL))            AS human_users,
  ROUND(COUNTIF(bot_status = 'possible_bot') * 100.0 / NULLIF(COUNT(*), 0), 2)    AS bot_pct
FROM base
GROUP BY 1
ORDER BY 1;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. DISTRIBUZIONE SCORE — quanti eventi per fascia di score
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'bot_score'),
      (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
    ) AS bot_score,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') AS bot_status
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
)
SELECT
  bot_score,
  bot_status,
  COUNT(*)                                                                AS events,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)                    AS pct_total
FROM base
WHERE bot_score IS NOT NULL
GROUP BY 1, 2
ORDER BY 1 DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. ANALISI SEGNALI — frequenza di ciascun segnale bot
--    I segnali sono pipe-separated: "wdt|np|dh0|nmm"
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_signal') AS bot_signal
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
),
signals_split AS (
  SELECT signal
  FROM base,
  UNNEST(SPLIT(bot_signal, '|')) AS signal
  WHERE bot_signal IS NOT NULL
    AND TRIM(signal) != ''
)
SELECT
  signal,
  -- Descrizione leggibile del segnale
  CASE signal
    WHEN 'wd'   THEN 'webdriver=true (+5)'
    WHEN 'hc'   THEN 'headlessChrome/Selenium in UA (+4)'
    WHEN 'np'   THEN 'plugins.length=0 (+2)'
    WHEN 'nc'   THEN 'window.chrome assente su Chrome UA (+3)'
    WHEN 'dw'   THEN 'deltaWidth<0 (+3)'
    WHEN 'dh0'  THEN 'deltaHeight<=0 (+3)'
    WHEN 'mt'   THEN 'mobile UA + no touch (+3)'
    WHEN 'ad'   THEN 'apple device + dpr<2 (+3)'
    WHEN 'cd'   THEN 'colorDepth<16 (+2)'
    WHEN 'dpr'  THEN 'dpr<1 (+2)'
    WHEN 'dt'   THEN 'desktop UA + touch + small screen (+2)'
    WHEN 'ce'   THEN 'canvasEmpty (+3)'
    WHEN 'cb'   THEN 'canvasBlocked (+1)'
    WHEN 'sr'   THEN 'softwareRenderer (+3)'
    WHEN 'nwg'  THEN 'noWebGL (+2)'
    WHEN 'we'   THEN 'webglError (+1)'
    WHEN 'nl'   THEN 'noLanguage (+2)'
    WHEN 'lu'   THEN 'lang+tz=UTC (+2)'
    WHEN 'nd'   THEN 'notificationsDenied (+1)'
    WHEN 'nmm'  THEN 'noMouseMove (+2)'
    WHEN 'ns'   THEN 'noScroll (+1)'
    WHEN 'tmp'  THEN 'tampering (+5)'
    WHEN 'sm'   THEN 'syntheticMouse (+4)'
    WHEN 'ss'   THEN 'syntheticScroll (+3)'
    WHEN 'lme'  THEN 'lowMouseEntropy (+2)'
    WHEN 'mf'   THEN 'mouseTooFast (+2)'
    WHEN 'wdt'  THEN 'webdriver=true [alias] (+5)'
    ELSE signal
  END                                                                     AS signal_description,
  COUNT(*)                                                                AS occurrences,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)                    AS pct_of_signals
FROM signals_split
GROUP BY 1, 2
ORDER BY 3 DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. COMBINAZIONI DI SEGNALI — top fingerprint bot
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_signal') AS bot_signal,
    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'bot_score'),
      (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
    ) AS bot_score
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
)
SELECT
  bot_signal                                                              AS signal_combination,
  COUNT(*)                                                                AS events,
  ROUND(AVG(bot_score), 1)                                               AS avg_score,
  MAX(bot_score)                                                          AS max_score,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)                    AS pct_total
FROM base
WHERE bot_signal IS NOT NULL
  AND bot_signal != ''
GROUP BY 1
ORDER BY 2 DESC
LIMIT 30;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. PAGINE PIÙ COLPITE — dove arriva il traffico bot
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    REGEXP_REPLACE(
      (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'),
      r'\?.*', ''
    )                                                                     AS page_url,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') AS bot_status
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
    AND event_name = 'page_view'
)
SELECT
  page_url,
  COUNTIF(bot_status = 'possible_bot')                                    AS bot_pageviews,
  COUNTIF(bot_status = 'normal_user')                                     AS human_pageviews,
  ROUND(
    COUNTIF(bot_status = 'possible_bot') * 100.0 /
    NULLIF(COUNTIF(bot_status = 'normal_user') + COUNTIF(bot_status = 'possible_bot'), 0),
    2
  )                                                                        AS bot_pct
FROM base
GROUP BY 1
HAVING bot_pageviews > 5
ORDER BY bot_pct DESC
LIMIT 50;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7. EVENTI CONVERSION INQUINATI — bot su eventi critici
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    event_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') AS bot_status,
    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'bot_score'),
      (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
    ) AS bot_score
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
    AND event_name IN (
      'purchase', 'generate_lead', 'begin_checkout',
      'add_to_cart', 'sign_up', 'form_submit', 'contact'
    )
)
SELECT
  event_name,
  COUNTIF(bot_status = 'possible_bot')                                    AS bot_conversions,
  COUNTIF(bot_status = 'normal_user')                                     AS human_conversions,
  ROUND(
    COUNTIF(bot_status = 'possible_bot') * 100.0 /
    NULLIF(COUNT(*), 0), 2
  )                                                                        AS bot_pct,
  ROUND(AVG(IF(bot_status = 'possible_bot', bot_score, NULL)), 1)        AS avg_bot_score
FROM base
GROUP BY 1
ORDER BY bot_conversions DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 8. BREAKDOWN DEVICE / OS / BROWSER — profilo tecnico dei bot
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    device.category         AS device_category,
    device.operating_system AS os,
    device.browser          AS browser,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') AS bot_status
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
)
SELECT
  device_category,
  os,
  browser,
  COUNTIF(bot_status = 'possible_bot')                                    AS bot_events,
  COUNTIF(bot_status = 'normal_user')                                     AS human_events,
  ROUND(
    COUNTIF(bot_status = 'possible_bot') * 100.0 / NULLIF(COUNT(*), 0),
    2
  )                                                                        AS bot_pct
FROM base
WHERE bot_status IS NOT NULL
GROUP BY 1, 2, 3
HAVING bot_events > 10
ORDER BY bot_pct DESC
LIMIT 40;


-- ─────────────────────────────────────────────────────────────────────────────
-- 9. GEO ANALYSIS — distribuzione geografica dei bot
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    geo.country AS country,
    geo.city    AS city,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') AS bot_status
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
)
SELECT
  country,
  city,
  COUNTIF(bot_status = 'possible_bot')                                    AS bot_events,
  COUNTIF(bot_status = 'normal_user')                                     AS human_events,
  ROUND(
    COUNTIF(bot_status = 'possible_bot') * 100.0 / NULLIF(COUNT(*), 0),
    2
  )                                                                        AS bot_pct
FROM base
WHERE bot_status IS NOT NULL
GROUP BY 1, 2
HAVING bot_events > 5
ORDER BY bot_events DESC
LIMIT 50;


-- ─────────────────────────────────────────────────────────────────────────────
-- 10. SESSIONI BOT — profilo completo di una sessione sospetta
--     Utile per debug e validazione della detection
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    user_pseudo_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id') AS session_id,
    event_name,
    event_timestamp,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status')    AS bot_status,
    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'bot_score'),
      (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
    )                                                                                  AS bot_score,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_signal')    AS bot_signal,
    device.browser          AS browser,
    device.operating_system AS os,
    geo.country             AS country
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
),
bot_sessions AS (
  SELECT DISTINCT session_id
  FROM base
  WHERE bot_status = 'possible_bot'
)
SELECT
  b.user_pseudo_id,
  b.session_id,
  b.event_name,
  TIMESTAMP_MICROS(b.event_timestamp)  AS event_time,
  b.page_location,
  b.bot_status,
  b.bot_score,
  b.bot_signal,
  b.browser,
  b.os,
  b.country
FROM base b
INNER JOIN bot_sessions s ON b.session_id = s.session_id
ORDER BY b.user_pseudo_id, b.event_timestamp
LIMIT 500;


-- ─────────────────────────────────────────────────────────────────────────────
-- 11. IMPATTO REVENUE — valore transazioni bot (e-commerce)
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') AS bot_status,
    ecommerce.purchase_revenue                                            AS revenue,
    ecommerce.transaction_id                                              AS transaction_id
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
    AND event_name = 'purchase'
)
SELECT
  COALESCE(bot_status, 'unknown')                                         AS bot_status,
  COUNT(DISTINCT transaction_id)                                          AS transactions,
  ROUND(SUM(revenue), 2)                                                  AS total_revenue,
  ROUND(AVG(revenue), 2)                                                  AS avg_order_value,
  ROUND(SUM(revenue) * 100.0 / SUM(SUM(revenue)) OVER (), 2)            AS pct_revenue
FROM base
GROUP BY 1
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 12. INDICE DI RISCHIO PER SEGNALE — quanto ogni segnale pesa sul totale bot
--     Utile per capire se ricalibrate la soglia o il peso dei segnali
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_signal') AS bot_signal,
    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'bot_score'),
      (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
    ) AS bot_score
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
    AND (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') = 'possible_bot'
),
signals_split AS (
  SELECT
    signal,
    bot_score
  FROM base,
  UNNEST(SPLIT(bot_signal, '|')) AS signal
  WHERE bot_signal IS NOT NULL
    AND TRIM(signal) != ''
)
SELECT
  signal,
  COUNT(*)                                                                AS occurrences,
  ROUND(AVG(bot_score), 1)                                               AS avg_total_score,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)                   AS pct_of_bot_events,
  -- Frequenza: segnale molto comune = probabilmente poco discriminante da solo
  CASE
    WHEN COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () > 80 THEN 'baseline (quasi tutti i bot)'
    WHEN COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () > 40 THEN 'comune'
    WHEN COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () > 15 THEN 'moderato'
    ELSE 'specifico (fingerprint preciso)'
  END                                                                     AS signal_role
FROM signals_split
GROUP BY 1
ORDER BY 2 DESC;
