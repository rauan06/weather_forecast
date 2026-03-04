# 🌩️ Weather Anomaly Detection — Kazakhstan

Detects anomalous weather events over Kazakhstan using historical ERA5 reanalysis data to train an Isolation Forest, then runs real-time inference on live Windy API forecasts.

## Core Idea

Isolation Forest is an unsupervised anomaly detection algorithm — it doesn't need labeled anomalies to train. It learns what "normal" weather looks like from 2 years of ERA5 data across the full KZ grid, then flags Windy forecast points that deviate from that learned distribution.

Three variables drive the model:
- **vent** — wind speed (m/s), derived from U/V components
- **pluie** — 3h precipitation accumulation (m)
- **temp** — air temperature (K)

# Road Section Application & The Coordinate Problem
The end goal is road safety — detecting weather anomalies along Kazakhstan's road sections in real time, so hazardous conditions can be flagged before incidents occur.
The approach: train the Isolation Forest on ERA5 historical anomalies covering the full KZ grid, then use live forecast data to score road segments. ERA5 gives us a rich baseline of what "abnormal" weather looks like across the entire country, not just a handful of cities.
The hard problem is coordinate resolution. Kazakhstan's road network contains thousands of segments, each of which would ideally be queried independently for live weather. But point-forecast APIs like Windy cap at 10,000 requests/day — querying every road coordinate individually would burn through that instantly and still not cover the full sections.


## ERA5 → Windy Sync

The two data sources speak slightly different dialects — the pipeline normalizes them before any data hits the model:

| Issue | ERA5 | Windy | Fix |
|---|---|---|---|
| Wind | U/V components | U/V components | `√(u²+v²)` on both |
| Precip | Cumulative, resets at 00/12 UTC | 3h rolling (`past3hprecip`) | Diff ERA5 within each 00–12 window |
| Temp | Kelvin | Kelvin | No conversion needed |
| Time | Hourly | 3h steps | ERA5 downsampled to 3h |

## Pipeline

```
ERA5 (2024–2025, 0.25° KZ grid)
    └── unzip → preprocess → TimescaleDB (era5_observations)
            └── train Isolation Forest + StandardScaler

Windy API (live, point forecasts)
    └── fetch → normalize → TimescaleDB (windy_forecasts)
            └── inference → anomaly_score, is_anomaly
                    └── TimescaleDB (anomaly_scores)
```

## Stack

- **Data**: ERA5 via CDS API, Windy Point Forecast API
- **Storage**: TimescaleDB (3 hypertables)
- **Model**: `sklearn.IsolationForest` + `StandardScaler`
- **Serialization**: `joblib` (model + scaler saved to disk)

## Setup

```bash
pip install -r requirements.txt
cp .env.example .env  # fill in your keys
# add ERA5 credentials to ~/.cdsapirc
jupyter notebook weather_anomaly_pipeline.ipynb
```