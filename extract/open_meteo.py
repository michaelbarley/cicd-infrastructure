"""
Extract daily weather data from the Open-Meteo archive API for 10 UK cities
and load into raw.weather_daily in PostgreSQL.
"""

import argparse
import logging
import sys

import psycopg2
import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

CITIES = [
    {"city": "London", "latitude": 51.507, "longitude": -0.128},
    {"city": "Manchester", "latitude": 53.483, "longitude": -2.244},
    {"city": "Birmingham", "latitude": 52.489, "longitude": -1.898},
    {"city": "Leeds", "latitude": 53.801, "longitude": -1.549},
    {"city": "Glasgow", "latitude": 55.861, "longitude": -4.250},
    {"city": "Edinburgh", "latitude": 55.953, "longitude": -3.189},
    {"city": "Liverpool", "latitude": 53.408, "longitude": -2.992},
    {"city": "Bristol", "latitude": 51.455, "longitude": -2.588},
    {"city": "Cardiff", "latitude": 51.481, "longitude": -3.179},
    {"city": "Belfast", "latitude": 54.597, "longitude": -5.930},
]

API_URL = "https://archive-api.open-meteo.com/v1/archive"

DAILY_VARS = "temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max"

DB_CONN = {
    "host": "weather-postgres",
    "port": 5432,
    "dbname": "warehouse",
    "user": "airflow",
    "password": "airflow",
}


def fetch_weather(city: dict, date: str) -> dict | None:
    """Fetch daily weather data for a single city and date."""
    params = {
        "latitude": city["latitude"],
        "longitude": city["longitude"],
        "start_date": date,
        "end_date": date,
        "daily": DAILY_VARS,
        "timezone": "Europe/London",
    }

    response = requests.get(API_URL, params=params, timeout=30)
    response.raise_for_status()

    data = response.json()
    daily = data.get("daily", {})

    if not daily.get("time"):
        logger.warning("No data returned for %s on %s", city["city"], date)
        return None

    return {
        "city": city["city"],
        "latitude": city["latitude"],
        "longitude": city["longitude"],
        "date": daily["time"][0],
        "temperature_max": daily["temperature_2m_max"][0],
        "temperature_min": daily["temperature_2m_min"][0],
        "precipitation": daily["precipitation_sum"][0],
        "wind_speed_max": daily["wind_speed_10m_max"][0],
    }


def load_weather(records: list[dict], date: str) -> None:
    """Delete existing rows for the date, then insert new records."""
    conn = psycopg2.connect(**DB_CONN)
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM raw.weather_daily WHERE date = %s", (date,))
            deleted = cur.rowcount
            if deleted:
                logger.info("Deleted %d existing rows for %s", deleted, date)

            for rec in records:
                cur.execute(
                    """
                    INSERT INTO raw.weather_daily
                        (city, latitude, longitude, date,
                         temperature_max, temperature_min, precipitation, wind_speed_max)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        rec["city"],
                        rec["latitude"],
                        rec["longitude"],
                        rec["date"],
                        rec["temperature_max"],
                        rec["temperature_min"],
                        rec["precipitation"],
                        rec["wind_speed_max"],
                    ),
                )

            conn.commit()
            logger.info("Inserted %d rows for %s", len(records), date)
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description="Extract weather data from Open-Meteo")
    parser.add_argument("date", help="Date to extract in YYYY-MM-DD format")
    args = parser.parse_args()

    logger.info("Starting extraction for %s", args.date)

    records = []
    for city in CITIES:
        try:
            record = fetch_weather(city, args.date)
            if record:
                records.append(record)
                logger.info("Fetched data for %s", city["city"])
        except requests.RequestException as e:
            logger.error("Failed to fetch data for %s: %s", city["city"], e)

    if not records:
        logger.error("No records fetched for %s, aborting", args.date)
        sys.exit(1)

    load_weather(records, args.date)
    logger.info("Extraction complete: %d/%d cities loaded", len(records), len(CITIES))


if __name__ == "__main__":
    main()
