-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ─────────────────────────────────────────
-- 1. ERA5 historical data (training source)
-- ─────────────────────────────────────────
CREATE TABLE era5_observations (
    time            TIMESTAMPTZ     NOT NULL,
    lat             DOUBLE PRECISION NOT NULL,
    lon             DOUBLE PRECISION NOT NULL,

    -- vent: U/V components + derived scalar speed
    wind_u          REAL,                        -- m/s, westward→eastward
    wind_v          REAL,                        -- m/s, southward→northward
    wind_speed      REAL GENERATED ALWAYS AS
                        (SQRT(wind_u^2 + wind_v^2)) STORED,

    -- pluie: 3h accumulated precip (pre-bucketed from ERA5 cumulative)
    precip_3h       REAL,                        -- m (water column)

    -- temp: 2m temperature
    temp_k          REAL,                        -- Kelvin

    PRIMARY KEY (time, lat, lon)
);

SELECT create_hypertable('era5_observations', 'time');

CREATE INDEX ON era5_observations (lat, lon, time DESC);


-- ─────────────────────────────────────────
-- 2. Windy live forecasts (inference source)
-- ─────────────────────────────────────────
CREATE TABLE windy_forecasts (
    time            TIMESTAMPTZ     NOT NULL,   -- forecast valid time (ts[] from API)
    fetched_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    lat             DOUBLE PRECISION NOT NULL,
    lon             DOUBLE PRECISION NOT NULL,
    model           TEXT            NOT NULL,   -- 'gfs', 'iconEu', 'arome', …

    wind_u          REAL,                        -- wind_u-surface, m/s
    wind_v          REAL,                        -- wind_v-surface, m/s
    wind_speed      REAL GENERATED ALWAYS AS
                        (SQRT(wind_u^2 + wind_v^2)) STORED,

    precip_3h       REAL,                        -- past3hprecip-surface, m
    temp_k          REAL,                        -- temp-surface, K

    PRIMARY KEY (time, lat, lon, model)
);

SELECT create_hypertable('windy_forecasts', 'time');

CREATE INDEX ON windy_forecasts (lat, lon, time DESC);
CREATE INDEX ON windy_forecasts (fetched_at DESC);


-- ─────────────────────────────────────────
-- 3. Anomaly scores (Isolation Forest output)
-- ─────────────────────────────────────────
CREATE TABLE anomaly_scores (
    time            TIMESTAMPTZ     NOT NULL,
    lat             DOUBLE PRECISION NOT NULL,
    lon             DOUBLE PRECISION NOT NULL,
    source          TEXT            NOT NULL,   -- 'era5' | 'windy'

    anomaly_score   REAL            NOT NULL,   -- raw IF score
    is_anomaly      BOOLEAN         NOT NULL,   -- threshold decision
    threshold       REAL,                        -- threshold used at inference time

    -- snapshot of the features that produced this score
    wind_speed      REAL,
    precip_3h       REAL,
    temp_k          REAL,

    PRIMARY KEY (time, lat, lon, source)
);

SELECT create_hypertable('anomaly_scores', 'time');

CREATE INDEX ON anomaly_scores (is_anomaly, time DESC);
CREATE INDEX ON anomaly_scores (lat, lon, time DESC);