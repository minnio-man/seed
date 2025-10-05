# syntax=docker/dockerfile:1.7
FROM python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1         PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends curl build-essential && rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh &&         ln -s /root/.local/bin/uv /usr/local/bin/uv

WORKDIR /app

# Copy service pyproject first
COPY services/web/pyproject.toml /app/services/web/pyproject.toml

RUN mkdir -p /app/services/web/webapp /app/services/web/templates

WORKDIR /app/services/web
RUN uv sync --no-dev --frozen

FROM python:3.11-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1         PYTHONUNBUFFERED=1         PATH="/app/services/web/.venv/bin:$PATH"

COPY --from=base /app/services/web/.venv /app/services/web/.venv

WORKDIR /app
COPY services/web/ /app/services/web/

# Add entrypoint
WORKDIR /app/services/web
COPY services/web/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8001
ENV FASTAPI_BASE_URL="http://api:8000"

ENTRYPOINT ["/entrypoint.sh"]
