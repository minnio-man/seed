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
COPY services/worker/pyproject.toml /app/services/worker/pyproject.toml

# Create empty dir so uv can resolve package
RUN mkdir -p /app/services/worker/worker

# Sync prod deps to a virtualenv under /.venv
WORKDIR /app/services/worker
RUN uv sync --no-dev --frozen

# Runtime image
FROM python:3.11-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/services/worker/.venv/bin:$PATH"

# Copy venv from build stage
COPY --from=base /app/services/worker/.venv /app/services/worker/.venv

# Copy source
WORKDIR /app
COPY services/worker/ /app/services/worker/

WORKDIR /app/services/worker
CMD ["python", "-m", "worker.main"]


