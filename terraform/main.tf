terraform {
  required_version = ">= 1.5"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

# ---------- Network ----------

resource "docker_network" "pipeline" {
  name = "weather-pipeline"
}

# ---------- Volume ----------

resource "docker_volume" "postgres_data" {
  name = "weather-pipeline-pgdata"
}

# ---------- Images ----------

resource "docker_image" "postgres" {
  name         = "postgres:16"
  keep_locally = true
}

resource "docker_image" "airflow" {
  name = "weather-pipeline-airflow:latest"

  build {
    context    = "${path.module}/.."
    dockerfile = "Dockerfile"
  }
}

# ---------- PostgreSQL ----------

resource "docker_container" "postgres" {
  name  = "weather-postgres"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=airflow",
  ]

  ports {
    internal = 5432
    external = var.postgres_port
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  volumes {
    host_path      = abspath("${path.module}/../scripts/init-db.sh")
    container_path = "/docker-entrypoint-initdb.d/init-db.sh"
  }

  networks_advanced {
    name = docker_network.pipeline.id
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U ${var.postgres_user}"]
    interval = "5s"
    retries  = 5
  }

  wait         = true
  wait_timeout = 60
}

# ---------- Airflow init (one-shot) ----------

resource "docker_container" "airflow_init" {
  name     = "weather-airflow-init"
  image    = docker_image.airflow.image_id
  must_run = false
  attach   = true
  logs     = true

  env = [
    "AIRFLOW__CORE__EXECUTOR=LocalExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${var.postgres_user}:${var.postgres_password}@weather-postgres:5432/airflow",
    "AIRFLOW__CORE__FERNET_KEY=",
    "AIRFLOW__CORE__LOAD_EXAMPLES=false",
  ]

  volumes {
    host_path      = abspath("${path.module}/../scripts/init-airflow.sh")
    container_path = "/init-airflow.sh"
    read_only      = true
  }

  entrypoint = ["/bin/bash"]
  command    = ["/init-airflow.sh"]

  networks_advanced {
    name = docker_network.pipeline.id
  }

  depends_on = [docker_container.postgres]
}

# ---------- Airflow webserver ----------

resource "docker_container" "airflow_webserver" {
  name  = "weather-airflow-webserver"
  image = docker_image.airflow.image_id

  env = [
    "AIRFLOW__CORE__EXECUTOR=LocalExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${var.postgres_user}:${var.postgres_password}@weather-postgres:5432/airflow",
    "AIRFLOW__CORE__FERNET_KEY=",
    "AIRFLOW__CORE__LOAD_EXAMPLES=false",
    "AIRFLOW__WEBSERVER__EXPOSE_CONFIG=true",
  ]

  ports {
    internal = 8080
    external = var.airflow_port
  }

  volumes {
    host_path      = abspath("${path.module}/../dags")
    container_path = "/opt/airflow/dags"
  }

  volumes {
    host_path      = abspath("${path.module}/../extract")
    container_path = "/opt/airflow/extract"
  }

  volumes {
    host_path      = abspath("${path.module}/../dbt_project")
    container_path = "/opt/airflow/dbt_project"
  }

  command = ["airflow", "webserver"]

  networks_advanced {
    name = docker_network.pipeline.id
  }

  depends_on = [docker_container.airflow_init]
}

# ---------- Airflow scheduler ----------

resource "docker_container" "airflow_scheduler" {
  name  = "weather-airflow-scheduler"
  image = docker_image.airflow.image_id

  env = [
    "AIRFLOW__CORE__EXECUTOR=LocalExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${var.postgres_user}:${var.postgres_password}@weather-postgres:5432/airflow",
    "AIRFLOW__CORE__FERNET_KEY=",
    "AIRFLOW__CORE__LOAD_EXAMPLES=false",
  ]

  volumes {
    host_path      = abspath("${path.module}/../dags")
    container_path = "/opt/airflow/dags"
  }

  volumes {
    host_path      = abspath("${path.module}/../extract")
    container_path = "/opt/airflow/extract"
  }

  volumes {
    host_path      = abspath("${path.module}/../dbt_project")
    container_path = "/opt/airflow/dbt_project"
  }

  command = ["airflow", "scheduler"]
  restart = "on-failure"

  networks_advanced {
    name = docker_network.pipeline.id
  }

  depends_on = [docker_container.airflow_init]
}
