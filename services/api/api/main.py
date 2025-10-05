from fastapi import FastAPI
from dotenv import load_dotenv
load_dotenv()
from util_math import mean, add
import os
import json
import threading
import time
import logging
import boto3
from sqlalchemy import create_engine, text

app = FastAPI(title="API Service")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/add")
def add_route(a: float, b: float):
    return {"sum": add(a, b)}

@app.post("/mean")
def mean_route(values: list[float]):
    return {"mean": mean(values)}


# Background SQS consumer (polls LocalStack SQS and logs/persists)
logger = logging.getLogger("sqs-consumer")
logger.setLevel(logging.INFO)

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql+psycopg://dbmaster:dbpassword@127.0.0.1:5432/application")
engine = create_engine(DATABASE_URL, future=True)

def ensure_table_exists() -> None:
    with engine.begin() as conn:
        try:
            conn.execute(text(
                """
                CREATE TABLE IF NOT EXISTS api_events (
                  id SERIAL PRIMARY KEY,
                  payload JSONB,
                  created_at TIMESTAMPTZ DEFAULT NOW()
                );
                """
            ))
        except Exception as e:
            logger.error("DB init error: %s", e)

def consume_sqs_loop() -> None:
    endpoint = os.environ.get("AWS_ENDPOINT_URL")
    region = os.environ.get("AWS_REGION", "ap-southeast-2")
    queue_url = os.environ.get("CREWVIA_TRIGGER_EVENT_QUEUE")
    if not queue_url:
        print("[consumer] Queue URL not set; consumer disabled")
        return
    print(f"[consumer] Starting with endpoint={endpoint} region={region} queue_url={queue_url}")
    sqs = boto3.client(
        "sqs",
        endpoint_url=endpoint,
        region_name=region,
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", "test"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
    )
    ensure_table_exists()
    while True:
        try:
            resp = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=5, WaitTimeSeconds=5)
            for m in resp.get("Messages", []):
                body = m.get("Body", "{}")
                print("[consumer] Received SQS message:", body)
                try:
                    payload = json.loads(body)
                except Exception:
                    payload = {"raw": body}
                with engine.begin() as conn:
                    conn.execute(text("INSERT INTO api_events (payload) VALUES (:p)"), {"p": json.dumps(payload)})
                sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=m["ReceiptHandle"])

                # Emit a domain event for the Worker to consume
                try:
                    events_endpoint = os.environ.get("AWS_EVENTS_ENDPOINT_URL", os.environ.get("AWS_ENDPOINT_URL"))
                    ev = boto3.client(
                        "events",
                        endpoint_url=events_endpoint,
                        region_name=region,
                        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", "test"),
                        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
                    )
                    original_message = payload.get("message") if isinstance(payload, dict) else None
                    composed = {
                        "message": f"user from web said: {original_message}" if original_message else str(payload)
                    }
                    ev.put_events(Entries=[{
                        "Source": os.environ.get("API_EVENT_SOURCE", "@minnio/crewvia-api"),
                        "DetailType": os.environ.get("CREWVIA_DOMAIN_EVENT_DETAIL_TYPE", "crewvia/domain-event"),
                        "Detail": json.dumps(composed),
                        "EventBusName": os.environ.get("EVENT_BUS_NAME", "default"),
                    }])
                    print("[consumer] Emitted domain event")
                except Exception as e:
                    print("[consumer] Domain event emit error:", e)
        except Exception as e:
            print("[consumer] SQS poll error:", e)
            time.sleep(2)


def start_consumer_thread() -> None:
    print("[consumer] Starting SQS consumer thread...")
    t = threading.Thread(target=consume_sqs_loop, daemon=True)
    t.start()


start_consumer_thread()
