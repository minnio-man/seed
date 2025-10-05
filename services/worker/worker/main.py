from dotenv import load_dotenv
load_dotenv()

import os
import time
import json
import boto3
from sqlalchemy import create_engine, text


def consume_sqs_loop() -> None:
    endpoint = os.environ.get("AWS_SQS_ENDPOINT_URL", os.environ.get("AWS_ENDPOINT_URL"))
    region = os.environ.get("AWS_REGION", "ap-southeast-2")
    queue_url = os.environ.get("CREWVIA_DOMAIN_EVENT_QUEUE") or os.environ.get("SQS_QUEUE_URL")

    if not queue_url:
        print("[worker] Queue URL not set; set CREWVIA_DOMAIN_EVENT_QUEUE or SQS_QUEUE_URL")
        return

    print(f"[worker] Starting with endpoint={endpoint} region={region} queue_url={queue_url}")
    sqs = boto3.client(
        "sqs",
        endpoint_url=endpoint,
        region_name=region,
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", "test"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
    )

    db_url = os.environ.get("DATABASE_URL")
    engine = create_engine(db_url, future=True) if db_url else None

    # Ensure table exists if persisting
    if engine is not None:
        try:
            with engine.begin() as conn:
                conn.execute(text(
                    """
                    CREATE TABLE IF NOT EXISTS worker_events (
                      id SERIAL PRIMARY KEY,
                      payload JSONB,
                      created_at TIMESTAMPTZ DEFAULT NOW()
                    );
                    """
                ))
        except Exception as e:
            print("[worker] DB init error:", e)

    while True:
        try:
            resp = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=5, WaitTimeSeconds=5)
            for m in resp.get("Messages", []):
                body = m.get("Body", "{}")
                print("[worker] Received SQS message:", body)
                try:
                    _payload = json.loads(body)
                except Exception:
                    _payload = {"raw": body}
                if engine is not None:
                    try:
                        with engine.begin() as conn:
                            conn.execute(text("INSERT INTO worker_events (payload) VALUES (:p)"), {"p": json.dumps(_payload)})
                    except Exception as e:
                        print("[worker] DB insert error:", e)
                sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=m["ReceiptHandle"])
        except Exception as e:
            print("[worker] SQS poll error:", e)
            time.sleep(2)


def main() -> None:
    consume_sqs_loop()


if __name__ == "__main__":
    main()
