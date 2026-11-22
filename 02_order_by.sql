-- Задание 2. Ключ сортировки и объём чтения.
-- Результаты и пояснения: results/Задание_2.md
-- Команды выполняются по одной, сверху вниз.
-- После SELECT сохраняется Read. Показатели Read самого EXPLAIN не используются.

-- 2.1. Подготовка таблиц. Сброс предыдущего опыта.
DROP TABLE IF EXISTS takt.hw_events_country;

DROP TABLE IF EXISTS takt.hw_events_time;

-- Таблица с ключом по времени; структура берётся из исходной таблицы.
CREATE TABLE takt.hw_events_time
AS takt.listening_events
ENGINE = MergeTree
ORDER BY (ended_at)
SETTINGS
    index_granularity = 8192,
    index_granularity_bytes = 0;

-- Та же структура, но ключ по стране и времени.
CREATE TABLE takt.hw_events_country
AS takt.hw_events_time
ENGINE = MergeTree
ORDER BY (country, ended_at)
SETTINGS
    index_granularity = 8192,
    index_granularity_bytes = 0;

-- Загрузка истории. Каждая вставка выполняется один раз.
INSERT INTO takt.hw_events_time
SELECT *
FROM takt.listening_events
WHERE ended_at >= toDateTime('2026-10-13 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-27 00:00:00', 'UTC');

-- Те же данные во второй таблице.
INSERT INTO takt.hw_events_country
SELECT * FROM takt.hw_events_time;

-- Слияние частей перед измерением.
OPTIMIZE TABLE takt.hw_events_time FINAL;

OPTIMIZE TABLE takt.hw_events_country FINAL;

-- Проверка: по одной активной части и 10 000 000 событий.
SELECT
    table,
    count() AS active_parts,
    sum(rows) AS events
FROM system.parts
WHERE database = 'takt'
  AND active
  AND table IN ('hw_events_time', 'hw_events_country')
GROUP BY table
ORDER BY table;

-- Определение таблицы с ключом по времени.
SHOW CREATE TABLE takt.hw_events_time;

-- Определение таблицы с составным ключом.
SHOW CREATE TABLE takt.hw_events_country;

-- 2.2. Запрос А: Германия, ключ ended_at.
SELECT
    country,
    count() AS events_total,
    countIf(played_seconds < 20) AS events_under_20,
    round(100.0 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_time
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
  AND country = 'DE'
GROUP BY country
ORDER BY country
SETTINGS
    max_threads = 4,
    use_query_cache = 0,
    use_query_condition_cache = 0,
    optimize_move_to_prewhere = 0;

-- План запроса А.
EXPLAIN indexes = 1
SELECT
    country,
    count() AS events_total,
    countIf(played_seconds < 20) AS events_under_20,
    round(100.0 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_time
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
  AND country = 'DE'
GROUP BY country
ORDER BY country
SETTINGS
    max_threads = 4,
    use_query_cache = 0,
    use_query_condition_cache = 0,
    optimize_move_to_prewhere = 0;

-- 2.2. Запрос Б: Германия, ключ (country, ended_at).
SELECT
    country,
    count() AS events_total,
    countIf(played_seconds < 20) AS events_under_20,
    round(100.0 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_country
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
  AND country = 'DE'
GROUP BY country
ORDER BY country
SETTINGS
    max_threads = 4,
    use_query_cache = 0,
    use_query_condition_cache = 0,
    optimize_move_to_prewhere = 0;

-- План запроса Б.
EXPLAIN indexes = 1
SELECT
    country,
    count() AS events_total,
    countIf(played_seconds < 20) AS events_under_20,
    round(100.0 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_country
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
  AND country = 'DE'
GROUP BY country
ORDER BY country
SETTINGS
    max_threads = 4,
    use_query_cache = 0,
    use_query_condition_cache = 0,
    optimize_move_to_prewhere = 0;

-- 2.2. Запрос В: все страны, ключ ended_at.
SELECT
    country,
    count() AS events_total,
    countIf(played_seconds < 20) AS events_under_20,
    round(100.0 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_time
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
GROUP BY country
ORDER BY country
SETTINGS
    max_threads = 4,
    use_query_cache = 0,
    use_query_condition_cache = 0,
    optimize_move_to_prewhere = 0;

-- План запроса В.
EXPLAIN indexes = 1
SELECT
    country,
    count() AS events_total,
    countIf(played_seconds < 20) AS events_under_20,
    round(100.0 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_time
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
GROUP BY country
ORDER BY country
SETTINGS
    max_threads = 4,
    use_query_cache = 0,
    use_query_condition_cache = 0,
    optimize_move_to_prewhere = 0;

-- 2.2. Запрос Г: все страны, ключ (country, ended_at).
SELECT
    country,
    count() AS events_total,
    countIf(played_seconds < 20) AS events_under_20,
    round(100.0 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_country
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
GROUP BY country
ORDER BY country
SETTINGS
    max_threads = 4,
    use_query_cache = 0,
    use_query_condition_cache = 0,
    optimize_move_to_prewhere = 0;

-- План запроса Г.
EXPLAIN indexes = 1
SELECT
    country,
    count() AS events_total,
    countIf(played_seconds < 20) AS events_under_20,
    round(100.0 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_country
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
GROUP BY country
ORDER BY country
SETTINGS
    max_threads = 4,
    use_query_cache = 0,
    use_query_condition_cache = 0,
    optimize_move_to_prewhere = 0;
