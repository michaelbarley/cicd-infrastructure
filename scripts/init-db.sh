#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE warehouse;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname warehouse <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS raw;

    CREATE TABLE IF NOT EXISTS raw.weather_daily (
        city            VARCHAR(100) NOT NULL,
        latitude        NUMERIC(6,3) NOT NULL,
        longitude       NUMERIC(6,3) NOT NULL,
        date            DATE NOT NULL,
        temperature_max NUMERIC(5,1),
        temperature_min NUMERIC(5,1),
        precipitation   NUMERIC(6,1),
        wind_speed_max  NUMERIC(5,1),
        loaded_at       TIMESTAMP DEFAULT NOW()
    );
EOSQL
