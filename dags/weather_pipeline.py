"""
Weather ELT pipeline DAG.

Extracts daily weather data from Open-Meteo for 10 UK cities,
transforms it through dbt staging and mart layers.
"""

from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

DBT_DIR = "/opt/airflow/dbt_project"

with DAG(
    dag_id="weather_pipeline",
    description="Daily weather ELT: extract from Open-Meteo, transform with dbt",
    schedule="@daily",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["weather", "elt"],
) as dag:

    extract_weather = BashOperator(
        task_id="extract_weather",
        bash_command="python /opt/airflow/extract/open_meteo.py {{ ds }}",
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"cd {DBT_DIR} && dbt seed --profiles-dir . && dbt run --profiles-dir .",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {DBT_DIR} && dbt test --profiles-dir .",
    )

    extract_weather >> dbt_run >> dbt_test
