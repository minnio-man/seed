# Worker Service

Consumes the domain SQS queue and processes events.

- Copy env: `cp env.sample .env`
- Run: `uv run python -m worker.main`
- Env: set `CREWVIA_DOMAIN_EVENT_QUEUE` (or `SQS_QUEUE_URL`), `AWS_ENDPOINT_URL`, `AWS_REGION`
