from fastapi.testclient import TestClient
from api.main import app

client = TestClient(app)

def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"

def test_add():
    r = client.get("/add", params={"a": 2, "b": 3})
    assert r.status_code == 200
    assert r.json()["sum"] == 5
