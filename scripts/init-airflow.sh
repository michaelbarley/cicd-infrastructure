#!/bin/bash
set -e

echo "Waiting for PostgreSQL..."
until python -c "
import socket
s = socket.create_connection(('weather-postgres', 5432), 2)
s.close()
" 2>/dev/null; do
    sleep 2
done

echo "Running database migrations..."
airflow db migrate

echo "Creating admin user..."
airflow users create \
    --username admin \
    --password admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com || true

echo "Init complete."
