"""Tests for the Items API.

These run in two places:
  1. Locally, so you get fast feedback while developing.
  2. In the CI pipeline (Milestone 5), as a gate before any image is
     pushed or deployed — a broken build never reaches AWS.

FastAPI's TestClient lets us call the app in-process (no running server),
so the tests are fast and need no network.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_then_fetch_item():
    create = client.post("/items", json={"name": "widget"})
    assert create.status_code == 201
    created = create.json()
    assert created["name"] == "widget"
    assert isinstance(created["id"], int)

    fetch = client.get(f"/items/{created['id']}")
    assert fetch.status_code == 200
    assert fetch.json()["name"] == "widget"


def test_fetch_missing_item_returns_404():
    response = client.get("/items/999999")
    assert response.status_code == 404
