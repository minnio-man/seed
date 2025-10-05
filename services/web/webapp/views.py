from django.shortcuts import render, redirect
from django.http import HttpRequest, HttpResponse
from django.conf import settings
from typing import cast
import os
import httpx
import boto3
import json

def home(request: HttpRequest) -> HttpResponse:
    return render(request, "home.html")

def sum_view(request: HttpRequest) -> HttpResponse:
    a_str = cast(str, request.GET.get("a", "2"))
    b_str = cast(str, request.GET.get("b", "3"))
    a = float(a_str)
    b = float(b_str)
    url = f"{settings.FASTAPI_BASE_URL}/add"
    with httpx.Client(timeout=5.0) as client:
        r = client.get(url, params={"a": a, "b": b})
        r.raise_for_status()
        data = r.json()
    return render(request, "result.html", {"a": a, "b": b, "result": data.get("sum")})

def health_view(request: HttpRequest) -> HttpResponse:
    url = f"{settings.FASTAPI_BASE_URL}/health"
    with httpx.Client(timeout=5.0) as client:
        r = client.get(url)
        r.raise_for_status()
        data = r.json()
    return render(request, "health.html", {"data": data})

def publish_event_view(request: HttpRequest) -> HttpResponse:
    if request.method == "POST":
        text = cast(str, request.POST.get("text", "")).strip()
        if text:
            client = boto3.client(
                "events",
                endpoint_url=os.environ.get("AWS_ENDPOINT_URL", None),
                region_name=os.environ.get("AWS_REGION", "ap-southeast-2"),
                aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", "test"),
                aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
            )
            detail = {"message": text}
            resp = client.put_events(
                Entries=[{
                    "Source": os.environ.get("API_EVENT_SOURCE", "@minnio/crewvia-api"),
                    "DetailType": os.environ.get("CREWVIA_TRIGGER_EVENT_DETAIL_TYPE", "crewvia/trigger-event"),
                    "Detail": json.dumps(detail),
                    "EventBusName": os.environ.get("EVENT_BUS_NAME", "default"),
                }]
            )
            # Temporary debug: print response so we can see failures
            try:
                print("PutEvents response:", resp)
            except Exception:
                pass
        return redirect("home")
    return render(request, "home.html")
