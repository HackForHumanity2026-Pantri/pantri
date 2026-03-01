import os
import sys
from pathlib import Path

# Must set env before imports
os.environ["DATABASE_URL"] = "sqlite:///test_pantri.db"
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from get_db import Base, get_db
from main import app
from models.models import Sources, Buses

TEST_DATABASE_URL = "sqlite:///test_pantri.db"
test_engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestSessionLocal = sessionmaker(bind=test_engine, autoflush=False, autocommit=False)


def override_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


def seed_test_source(db):
    source = Sources(
        id=1,
        name="Test Food Bank",
        type="Food Bank",
        duration="permanent",
        address="123 Main St",
        city="San Jose",
        state="CA",
        zip="95110",
        lat=37.3382,
        lng=-121.8863,
        phone="408-555-0101",
        hours_json=[
            {"day": "Mon", "open": "00:00", "close": "23:59"},
            {"day": "Tue", "open": "00:00", "close": "23:59"},
            {"day": "Wed", "open": "00:00", "close": "23:59"},
            {"day": "Thu", "open": "00:00", "close": "23:59"},
            {"day": "Fri", "open": "00:00", "close": "23:59"},
            {"day": "Sat", "open": "00:00", "close": "23:59"},
            {"day": "Sun", "open": "00:00", "close": "23:59"},
        ],
        types_json=["groceries", "fresh produce"],
        is_accessible=True,
        availability="high",
        excess_food=False,
    )
    db.add(source)
    db.commit()
    return source


def seed_test_bus(db):
    bus = Buses(id="BUS_1", name="Test Stop", lat=37.338, lng=-121.886)
    db.add(bus)
    db.commit()
    return bus


# ── GET /sources ──


def test_get_sources_empty():
    response = client.get("/sources")
    assert response.status_code == 200
    assert response.json() == []


def test_get_sources_with_data():
    db = TestSessionLocal()
    seed_test_source(db)
    db.close()

    response = client.get("/sources")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "Test Food Bank"
    assert data[0]["latitude"] == 37.3382
    assert data[0]["longitude"] == -121.8863
    assert data[0]["sourceType"] == "Food Bank"
    assert "Groceries" in data[0]["foodTypes"]
    assert data[0]["publicTransitAccessible"] is True
    assert isinstance(data[0]["id"], str)  # UUID string


def test_get_sources_with_location():
    db = TestSessionLocal()
    seed_test_source(db)
    db.close()

    response = client.get("/sources?lat=37.34&lng=-121.89")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["distance_km"] is not None
    assert data[0]["distance_km"] > 0


# ── GET /sources/search ──


def test_search_sources():
    db = TestSessionLocal()
    seed_test_source(db)
    db.close()

    response = client.get(
        "/sources/search",
        params={
            "food_type": "groceries",
            "urgent_level": "low",
            "transportation": "car",
            "lat": 37.34,
            "lng": -121.89,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert data[0]["name"] == "Test Food Bank"


def test_search_sources_no_match():
    db = TestSessionLocal()
    seed_test_source(db)
    db.close()

    response = client.get(
        "/sources/search",
        params={
            "food_type": "cooked meals",
            "urgent_level": "low",
            "transportation": "car",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 0


def test_search_sources_optional_params():
    """Verify /sources/search works without food_type, urgent_level, transportation."""
    db = TestSessionLocal()
    seed_test_source(db)
    db.close()

    response = client.get(
        "/sources/search",
        params={"lat": 37.34, "lng": -121.89},
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert data[0]["name"] == "Test Food Bank"


# ── POST /sources ──


def test_create_source():
    response = client.post(
        "/sources",
        json={
            "name": "New Food Bank",
            "phone": "555-0000",
            "types_json": ["groceries"],
            "duration": "permanent",
            "is_accessible": False,
            "availability": "medium",
            "excess_food": False,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "New Food Bank"
    assert isinstance(data["id"], str)  # UUID string


# ── POST /chat ──


def test_chat_greeting():
    response = client.post("/chat", json={"message": "hello"})
    assert response.status_code == 200
    data = response.json()
    assert "reply" in data
    assert "Pantri" in data["reply"]


def test_chat_food_query():
    response = client.post("/chat", json={"message": "I'm hungry"})
    assert response.status_code == 200
    data = response.json()
    assert "reply" in data


def test_chat_grocery_query():
    response = client.post("/chat", json={"message": "I need groceries"})
    assert response.status_code == 200
    data = response.json()
    assert "reply" in data


def test_chat_directions():
    response = client.post("/chat", json={"message": "how to get directions"})
    assert response.status_code == 200
    data = response.json()
    assert "Directions" in data["reply"]


def test_chat_thanks():
    response = client.post("/chat", json={"message": "thank you"})
    assert response.status_code == 200
    data = response.json()
    assert "welcome" in data["reply"].lower()


# ── POST /sms/send ──


def test_send_sms():
    response = client.post(
        "/sms/send",
        json={"to": "+14085550101", "body": "Test SMS message"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "sent"
    assert data["to"] == "+14085550101"


# ── POST /verify/{source_id} ──


def test_verify_source():
    db = TestSessionLocal()
    seed_test_source(db)
    db.close()

    response = client.post("/verify/1")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "verified"
    assert data["source_id"] == 1


def test_verify_source_not_found():
    response = client.post("/verify/999")
    assert response.status_code == 404


# ── POST /restaurants ──


def test_create_restaurant():
    response = client.post(
        "/restaurants",
        json={
            "name": "Test Restaurant",
            "phone": "555-1234",
            "types_json": ["cooked meals"],
            "duration": "permanent",
            "availability": "high",
            "excess_food": True,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Test Restaurant"


# ── Response format validation ──


def test_source_response_format():
    """Verify the response format matches what the iOS app expects."""
    db = TestSessionLocal()
    seed_test_source(db)
    db.close()

    response = client.get("/sources")
    data = response.json()[0]

    # Verify all fields the iOS app expects are present
    expected_fields = [
        "id", "name", "phone", "address", "city", "state",
        "latitude", "longitude",
        "sourceType", "foodTypes", "hoursOfOperation", "duration",
        "publicTransitAccessible", "availability", "hasExcessFood",
        "isVerified", "isOpen",
    ]
    for field in expected_fields:
        assert field in data, f"Missing field: {field}"

    # Type checks
    assert isinstance(data["id"], str)
    assert isinstance(data["latitude"], float)
    assert isinstance(data["longitude"], float)
    assert isinstance(data["foodTypes"], list)
    assert isinstance(data["publicTransitAccessible"], bool)
    assert isinstance(data["hasExcessFood"], bool)
    assert isinstance(data["isVerified"], bool)
    assert isinstance(data["isOpen"], bool)
