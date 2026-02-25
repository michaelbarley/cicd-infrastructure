.PHONY: up down plan test lint fmt

up:
	cd terraform && terraform init -input=false && terraform apply -auto-approve

down:
	cd terraform && terraform destroy -auto-approve

plan:
	cd terraform && terraform init -input=false && terraform plan

test:
	pytest tests/ -v
	docker exec weather-airflow-scheduler bash -c \
		"cd /opt/airflow/dbt_project && dbt test --profiles-dir ."

lint:
	ruff check .
	sqlfluff lint dbt_project/models/ --dialect postgres
	cd terraform && terraform fmt -check

fmt:
	ruff check --fix .
	cd terraform && terraform fmt
