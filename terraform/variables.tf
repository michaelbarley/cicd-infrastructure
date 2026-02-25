variable "docker_host" {
  description = "Docker daemon socket. Override if not using the default."
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "airflow"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  default     = "airflow"
}

variable "postgres_port" {
  description = "PostgreSQL host port"
  type        = number
  default     = 5432
}

variable "airflow_port" {
  description = "Airflow webserver host port"
  type        = number
  default     = 8080
}
