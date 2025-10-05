# syntax=docker/dockerfile:1.7
FROM python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends curl build-essential && rm -rf /var/lib/apt/lists/*

# Install uv (standalone)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

WORKDIR /app

# Copy only the service pyproject first (layer cache)
COPY services/api/pyproject.toml /app/services/api/pyproject.toml
# Copy package pyprojects for local path deps (no sources yet, maximize cache)
COPY packages/util_math/pyproject.toml /app/packages/util_math/pyproject.toml
COPY packages/data_io/pyproject.toml   /app/packages/data_io/pyproject.toml

# Create empty dirs so uv can resolve local deps layer-cached
RUN mkdir -p /app/services/api/api \
    && mkdir -p /app/packages/util_math/util_math \
    && mkdir -p /app/packages/data_io/data_io

# Sync prod deps (no dev) to a virtualenv under /.venv and cache wheels
WORKDIR /app/services/api
RUN uv sync --no-dev --frozen

# Runtime image
FROM python:3.11-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/services/api/.venv/bin:$PATH"

# Copy venv from build stage
COPY --from=base /app/services/api/.venv /app/services/api/.venv

# Copy source (services + packages)
WORKDIR /app
COPY packages/ /app/packages/
COPY services/api/ /app/services/api/

EXPOSE 8000
WORKDIR /app/services/api
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
