SHELL := /bin/bash
PROJECT_DIRS := $(shell find packages services -type f -name pyproject.toml -exec dirname {} \; 2>/dev/null)

.PHONY: bootstrap sync fmt lint type test cov run-api run-web run-worker tflocal-init tflocal-apply tflocal-env tflocal-destroy tflocal-validate localaws

bootstrap:
	pre-commit install

sync:
	@for d in $(PROJECT_DIRS); do \
		echo "=== uv sync in $$d"; \
		( cd "$$d" && uv sync ); \
	done

fmt:
	ruff format

lint:
	ruff check .

type:
	pyright

test:
	pytest

cov:
	coverage run -m pytest && coverage report -m

run-api:
	( cd services/api && uv run uvicorn api.main:app --reload --port 8000 )

run-web:
	( cd services/web && uv run python manage.py migrate && uv run python manage.py runserver 127.0.0.1:8001 )

run-worker:
	( cd services/worker && uv run python -m worker.main )

# Infrastructure (LocalStack/Terraform) helpers
TF_DIR := infra/services
APP_DOMAIN ?= crewvia-dev.minnio.software
AWS_ACCESS_KEY_ID ?= test
AWS_SECRET_ACCESS_KEY ?= test
AWS_DEFAULT_REGION ?= ap-southeast-2
LOCALSTACK ?= true
LOCALSTACK_ENDPOINT ?= http://localhost:4566
TF_INPUT ?= true

tflocal-init:
	tflocal -chdir=$(TF_DIR) init


tflocal-validate: tflocal-init
	tflocal -chdir=$(TF_DIR) validate


tflocal-apply:
	tflocal -chdir=$(TF_DIR) apply -input=$(TF_INPUT) -auto-approve \
		-var "AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID)" \
		-var "AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY)" \
		-var "LOCALSTACK=true" \
		-var "APP_DOMAIN=$(APP_DOMAIN)"

tflocal-env:
	tflocal -chdir=$(TF_DIR) output -json > .env.local

tflocal-destroy:
	tflocal -chdir=$(TF_DIR) destroy -input=false -auto-approve \
		-var "AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID)" \
		-var "AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY)" \
		-var "LOCALSTACK=$(LOCALSTACK)" \
		-var "APP_DOMAIN=$(APP_DOMAIN)"


# Usage: make localaws CMD="s3 ls" (or any aws subcommand)
localaws:
	AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) aws --endpoint-url=$(LOCALSTACK_ENDPOINT) $(CMD)
