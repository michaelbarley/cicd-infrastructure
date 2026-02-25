output "airflow_url" {
  description = "Airflow webserver URL"
  value       = "http://localhost:${var.airflow_port}"
}

output "postgres_connection" {
  description = "psql command to connect to the warehouse database"
  value       = "docker exec -it weather-postgres psql -U ${var.postgres_user} -d warehouse"
}
