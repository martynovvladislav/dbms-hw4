-- Подготовка стенда по готовому блоку из задания.
-- Выполнять команды по одной. Этот файл пересоздаёт исходную таблицу.
-- Повторять только весь блок: отдельный INSERT удвоит данные.
-- Результаты проверок: results/Подготовка.md

-- База данных.
CREATE DATABASE IF NOT EXISTS takt;

-- Сброс исходной таблицы перед загрузкой.
DROP TABLE IF EXISTS takt.listening_events;

-- Исходная схема.
CREATE TABLE takt.listening_events
(
    ended_at       DateTime('UTC') CODEC(Delta, ZSTD),
    user_id        UInt64,
    track_id       UInt64,
    country        String,
    platform       String,
    app_version    String,
    played_seconds UInt32,
    track_seconds  UInt32
)
ENGINE = MergeTree
ORDER BY ended_at;

-- Загрузка listening_events.csv.gz из data в папке стенда.
INSERT INTO takt.listening_events
SELECT *
FROM file(
    'data/listening_events.csv.gz',
    'CSVWithNames',
    'ended_at DateTime(\'UTC\'), user_id UInt64, track_id UInt64, country String, platform String, app_version String, played_seconds UInt32, track_seconds UInt32'
);

-- Версия ClickHouse.
SELECT version();

-- Количество событий и границы времени (UTC).
SELECT count() AS events, min(ended_at) AS first_event, max(ended_at) AS last_event
FROM takt.listening_events;

-- Количество событий за 13–26 октября (UTC).
SELECT count() AS history_events
FROM takt.listening_events
WHERE ended_at >= toDateTime('2026-10-13 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-27 00:00:00', 'UTC');
