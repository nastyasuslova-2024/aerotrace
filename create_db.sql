-- =====================================================================
-- AeroTrace — Аналитический дашборд для мониторинга экологических показателей
-- SQL-скрипт создания базы данных
-- СУБД: PostgreSQL 14+
-- =====================================================================

DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS thresholds CASCADE;
DROP TABLE IF EXISTS measurements CASCADE;
DROP TABLE IF EXISTS sensors CASCADE;
DROP TABLE IF EXISTS reports CASCADE;
DROP TABLE IF EXISTS stations CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ---------------------------------------------------------------------
-- Пользователи системы (администраторы, аналитики, наблюдатели)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id              SERIAL PRIMARY KEY,
    username        VARCHAR(50)  NOT NULL UNIQUE,
    email           VARCHAR(100) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    role            VARCHAR(20)  NOT NULL DEFAULT 'observer'
                       CHECK (role IN ('admin', 'analyst', 'observer')),
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- Станции экологического мониторинга (точки размещения датчиков)
-- ---------------------------------------------------------------------
CREATE TABLE stations (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    latitude        DECIMAL(9,6) NOT NULL,
    longitude       DECIMAL(9,6) NOT NULL,
    description     TEXT,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- Датчики, установленные на станциях
-- ---------------------------------------------------------------------
CREATE TABLE sensors (
    id              SERIAL PRIMARY KEY,
    station_id      INTEGER      NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
    sensor_type     VARCHAR(20)  NOT NULL
                       CHECK (sensor_type IN ('temperature', 'humidity', 'co2', 'pm25')),
    model           VARCHAR(50),
    unit            VARCHAR(10)  NOT NULL,
    installed_at    DATE         NOT NULL DEFAULT CURRENT_DATE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_sensors_station ON sensors(station_id);
CREATE INDEX idx_sensors_type    ON sensors(sensor_type);

-- ---------------------------------------------------------------------
-- Показания датчиков (временной ряд)
-- ---------------------------------------------------------------------
CREATE TABLE measurements (
    id              BIGSERIAL PRIMARY KEY,
    sensor_id       INTEGER      NOT NULL REFERENCES sensors(id) ON DELETE CASCADE,
    value           DECIMAL(10,3) NOT NULL,
    recorded_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_measurements_sensor_time ON measurements(sensor_id, recorded_at DESC);

-- ---------------------------------------------------------------------
-- Пороговые значения для оповещений (глобальные либо для конкретной станции)
-- ---------------------------------------------------------------------
CREATE TABLE thresholds (
    id              SERIAL PRIMARY KEY,
    station_id      INTEGER      REFERENCES stations(id) ON DELETE CASCADE,
    sensor_type     VARCHAR(20)  NOT NULL
                       CHECK (sensor_type IN ('temperature', 'humidity', 'co2', 'pm25')),
    min_value       DECIMAL(10,3),
    max_value       DECIMAL(10,3),
    CONSTRAINT chk_threshold_range CHECK (min_value IS NULL OR max_value IS NULL OR min_value < max_value)
);

CREATE INDEX idx_thresholds_type ON thresholds(sensor_type);

-- ---------------------------------------------------------------------
-- Оповещения о превышении нормы
-- ---------------------------------------------------------------------
CREATE TABLE alerts (
    id              BIGSERIAL PRIMARY KEY,
    sensor_id       INTEGER      NOT NULL REFERENCES sensors(id) ON DELETE CASCADE,
    threshold_id    INTEGER      NOT NULL REFERENCES thresholds(id) ON DELETE CASCADE,
    measured_value  DECIMAL(10,3) NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'open'
                       CHECK (status IN ('open', 'acknowledged', 'resolved')),
    triggered_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at     TIMESTAMP
);

CREATE INDEX idx_alerts_status ON alerts(status);

-- ---------------------------------------------------------------------
-- Сформированные отчёты (экспорт исторических данных)
-- ---------------------------------------------------------------------
CREATE TABLE reports (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    station_id      INTEGER      NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
    period_start    DATE         NOT NULL,
    period_end      DATE         NOT NULL,
    file_format     VARCHAR(10)  NOT NULL DEFAULT 'pdf'
                       CHECK (file_format IN ('pdf', 'csv', 'xlsx')),
    generated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_report_period CHECK (period_start <= period_end)
);

-- ---------------------------------------------------------------------
-- Тестовые данные для проверки структуры
-- ---------------------------------------------------------------------
INSERT INTO users (username, email, password_hash, role) VALUES
    ('admin', 'admin@aerotrace.local', 'hash_placeholder_1', 'admin'),
    ('analyst01', 'analyst01@aerotrace.local', 'hash_placeholder_2', 'analyst');

INSERT INTO stations (name, latitude, longitude, description) VALUES
    ('Станция №1 — Центр города', 45.035470, 38.975313, 'Центральная площадь, зона высокой транспортной нагрузки'),
    ('Станция №2 — Парковая зона', 45.048000, 39.010000, 'Городской парк, контрольная точка фонового загрязнения');

INSERT INTO sensors (station_id, sensor_type, model, unit) VALUES
    (1, 'temperature', 'DHT22', '°C'),
    (1, 'humidity',    'DHT22', '%'),
    (1, 'co2',         'MH-Z19B', 'ppm'),
    (1, 'pm25',        'PMS5003', 'мкг/м³'),
    (2, 'temperature', 'DHT22', '°C'),
    (2, 'pm25',        'PMS5003', 'мкг/м³');

INSERT INTO thresholds (station_id, sensor_type, min_value, max_value) VALUES
    (NULL, 'co2',  NULL, 1000.000),
    (NULL, 'pm25', NULL, 35.000),
    (NULL, 'temperature', -10.000, 40.000);
