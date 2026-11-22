-- Задание 4. Почасовые итоги и материализованное представление.
-- Результаты и пояснения: results/Задание_4.md
-- Команды выполняются по одной, сверху вниз. INSERT истории, А и Б — по одному разу.
-- Для повторного опыта нужно начать со сброса объектов в начале файла.

-- 4.1. Подготовка. Сначала удаляется MV, затем учебные таблицы.
DROP VIEW IF EXISTS takt.hw_country_hourly_mv;

DROP TABLE IF EXISTS takt.hw_country_hourly;

DROP TABLE IF EXISTS takt.hw_mv_events;

-- Источник с тремя нужными полями.
CREATE TABLE takt.hw_mv_events
(
    ended_at       DateTime('UTC'),
    country        String,
    played_seconds UInt32
)
ENGINE = MergeTree
ORDER BY ended_at;

-- История загружается до создания MV.
INSERT INTO takt.hw_mv_events
SELECT ended_at, country, played_seconds
FROM takt.listening_events
WHERE ended_at >= toDateTime('2026-10-13 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-27 00:00:00', 'UTC');

-- Таблица итогов по часу и стране.
CREATE TABLE takt.hw_country_hourly
(
    hour            DateTime('UTC'),
    country         String,
    events          UInt64,
    events_under_20 UInt64,
    total_seconds   UInt64
)
ENGINE = SummingMergeTree(
    (events, events_under_20, total_seconds)
)
ORDER BY (hour, country);

-- Количество событий до опыта: ожидается 10 000 000.
SELECT count() AS source_events
FROM takt.hw_mv_events;

-- MV обрабатывает новые вставки без ограничения по дате.
CREATE MATERIALIZED VIEW takt.hw_country_hourly_mv
TO takt.hw_country_hourly
AS
SELECT
    toStartOfHour(ended_at) AS hour,
    country,
    count() AS events,
    countIf(played_seconds < 20) AS events_under_20,
    sum(played_seconds) AS total_seconds
FROM takt.hw_mv_events
GROUP BY hour, country;

-- После создания MV таблица итогов ещё пуста: ожидается 0.
SELECT count() AS stored_rows
FROM takt.hw_country_hourly;

-- 4.2. Однократное заполнение итогов по истории напрямую в target.
INSERT INTO takt.hw_country_hourly
    (hour, country, events, events_under_20, total_seconds)
SELECT
    toStartOfHour(ended_at) AS hour,
    country,
    count() AS events,
    countIf(played_seconds < 20) AS events_under_20,
    sum(played_seconds) AS total_seconds
FROM takt.hw_mv_events
GROUP BY hour, country;

-- Общий контроль после истории: ожидается 0 строк расхождений.
SELECT
    hour,
    country,
    sum(events_delta) AS events_diff,
    sum(short_delta) AS short_diff,
    sum(seconds_delta) AS seconds_diff
FROM
(
    SELECT
        toStartOfHour(ended_at) AS hour,
        country,
        toInt64(count()) AS events_delta,
        toInt64(countIf(played_seconds < 20)) AS short_delta,
        toInt64(sum(played_seconds)) AS seconds_delta
    FROM takt.hw_mv_events
    GROUP BY hour, country
    UNION ALL
    SELECT
        hour,
        country,
        -toInt64(events),
        -toInt64(events_under_20),
        -toInt64(total_seconds)
    FROM takt.hw_country_hourly
)
GROUP BY hour, country
HAVING events_diff != 0
    OR short_diff != 0
    OR seconds_diff != 0
ORDER BY hour, country;

-- 4.3. Порция А. После истории итоги пополняются только через MV.
INSERT INTO takt.hw_mv_events
    (ended_at, country, played_seconds)
VALUES
    ('2026-10-27 19:01:00', 'RU', 5),
    ('2026-10-27 19:02:00', 'RU', 19),
    ('2026-10-27 19:03:00', 'RU', 20),
    ('2026-10-27 19:04:00', 'RU', 40),
    ('2026-10-27 19:05:00', 'KZ', 25);

-- Отчёт после А: 27 октября, 19:00–21:00 UTC.
SELECT
    hour,
    country,
    sum(events) AS event_count,
    sum(events_under_20) AS short_count,
    sum(total_seconds) AS seconds_sum,
    round(100.0 * short_count / event_count, 2) AS under_20_percent,
    round(seconds_sum / event_count, 2) AS avg_seconds
FROM takt.hw_country_hourly
WHERE hour >= toDateTime('2026-10-27 19:00:00', 'UTC')
  AND hour <  toDateTime('2026-10-27 21:00:00', 'UTC')
GROUP BY hour, country
ORDER BY hour, country;

-- Общий контроль после А: ожидается 0 строк расхождений.
SELECT
    hour,
    country,
    sum(events_delta) AS events_diff,
    sum(short_delta) AS short_diff,
    sum(seconds_delta) AS seconds_diff
FROM
(
    SELECT
        toStartOfHour(ended_at) AS hour,
        country,
        toInt64(count()) AS events_delta,
        toInt64(countIf(played_seconds < 20)) AS short_delta,
        toInt64(sum(played_seconds)) AS seconds_delta
    FROM takt.hw_mv_events
    GROUP BY hour, country
    UNION ALL
    SELECT
        hour,
        country,
        -toInt64(events),
        -toInt64(events_under_20),
        -toInt64(total_seconds)
    FROM takt.hw_country_hourly
)
GROUP BY hour, country
HAVING events_diff != 0
    OR short_diff != 0
    OR seconds_diff != 0
ORDER BY hour, country;

-- 4.4. Историческая группа до Б: RU, 24 октября, 12:00 UTC.
SELECT
    hour,
    country,
    sum(events) AS event_count,
    sum(events_under_20) AS short_count,
    sum(total_seconds) AS seconds_sum,
    round(100.0 * short_count / event_count, 2) AS under_20_percent,
    round(seconds_sum / event_count, 2) AS avg_seconds
FROM takt.hw_country_hourly
WHERE hour = toDateTime('2026-10-24 12:00:00', 'UTC')
  AND country = 'RU'
GROUP BY hour, country
ORDER BY hour, country;

-- 4.3. Порция Б: два события за 27 октября и одно опоздавшее за 24 октября.
INSERT INTO takt.hw_mv_events
    (ended_at, country, played_seconds)
VALUES
    ('2026-10-27 19:00:00', 'RU', 1),
    ('2026-10-27 20:00:00', 'RU', 10),
    ('2026-10-24 12:34:00', 'RU', 7);

-- Отчёт после Б за те же новые часы.
SELECT
    hour,
    country,
    sum(events) AS event_count,
    sum(events_under_20) AS short_count,
    sum(total_seconds) AS seconds_sum,
    round(100.0 * short_count / event_count, 2) AS under_20_percent,
    round(seconds_sum / event_count, 2) AS avg_seconds
FROM takt.hw_country_hourly
WHERE hour >= toDateTime('2026-10-27 19:00:00', 'UTC')
  AND hour <  toDateTime('2026-10-27 21:00:00', 'UTC')
GROUP BY hour, country
ORDER BY hour, country;

-- 4.4. Историческая группа после Б: ожидается изменение +1 / +1 / +7.
SELECT
    hour,
    country,
    sum(events) AS event_count,
    sum(events_under_20) AS short_count,
    sum(total_seconds) AS seconds_sum,
    round(100.0 * short_count / event_count, 2) AS under_20_percent,
    round(seconds_sum / event_count, 2) AS avg_seconds
FROM takt.hw_country_hourly
WHERE hour = toDateTime('2026-10-24 12:00:00', 'UTC')
  AND country = 'RU'
GROUP BY hour, country
ORDER BY hour, country;

-- Общий контроль после Б: ожидается 0 строк расхождений.
SELECT
    hour,
    country,
    sum(events_delta) AS events_diff,
    sum(short_delta) AS short_diff,
    sum(seconds_delta) AS seconds_diff
FROM
(
    SELECT
        toStartOfHour(ended_at) AS hour,
        country,
        toInt64(count()) AS events_delta,
        toInt64(countIf(played_seconds < 20)) AS short_delta,
        toInt64(sum(played_seconds)) AS seconds_delta
    FROM takt.hw_mv_events
    GROUP BY hour, country
    UNION ALL
    SELECT
        hour,
        country,
        -toInt64(events),
        -toInt64(events_under_20),
        -toInt64(total_seconds)
    FROM takt.hw_country_hourly
)
GROUP BY hour, country
HAVING events_diff != 0
    OR short_diff != 0
    OR seconds_diff != 0
ORDER BY hour, country;

-- Итоговое количество событий источника: ожидается 10 000 008.
SELECT count() AS source_events
FROM takt.hw_mv_events;
