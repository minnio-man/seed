# Dockerized Dev

## Build & Run (Compose)
```bash
docker compose up --build
# API -> http://127.0.0.1:8000/health
# Web -> http://127.0.0.1:8001/
```
## Build images individually
```bash
# From repo root:
docker build -t api-service:dev -f services/api/Dockerfile .
docker build -t web-service:dev -f services/web/Dockerfile .
```
