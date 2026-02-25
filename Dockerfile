FROM apache/airflow:2.10.5

USER airflow

RUN pip install --no-cache-dir dbt-postgres==1.9.0
