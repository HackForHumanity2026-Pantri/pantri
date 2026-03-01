"""Tests for the voice-verification agent pipeline.

Ollama is mocked so tests run without a live LLM server.
"""

import os
import sys
import json
from pathlib import Path
from unittest.mock import patch, MagicMock
from datetime import datetime, timezone

import requests as requests_lib

# Must set env before imports
os.environ["DATABASE_URL"] = "sqlite:///test_pantri.db"
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from get_db import Base, get_db
from main import app
from models.models import Sources
from voice.models import PendingProposal, AuditLog
from voice.schemas import Change, ChangeRequest
from voice.db_apply import apply_changes, CONFIDENCE_THRESHOLD

TEST_DATABASE_URL = "sqlite:///test_pantri.db"
test_engine = create_engine(
    TEST_DATABASE_URL, connect_args={"check_same_thread": False}
)
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


def _seed_source(db):
    source = Sources(
        id=1,
        name="Test Food Bank",
        type="Food Bank",
        address="123 Main St",
        city="San Jose",
        state="CA",
        zip="95110",
        lat=37.3382,
        lng=-121.8863,
        phone="408-555-0101",
        hours_json=[{"day": "Mon", "open": "09:00", "close": "17:00"}],
        types_json=["groceries"],
        is_accessible=True,
        availability="high",
        excess_food=False,
    )
    db.add(source)
    db.commit()
    return source


# ── schemas tests ─────────────────────────────────────────────────────


def test_change_schema_valid():
    c = Change(field="phone", old_value="555-0000", new_value="555-1111", confidence=0.95)
    assert c.field == "phone"
    assert c.confidence == 0.95


def test_change_schema_confidence_bounds():
    with pytest.raises(Exception):
        Change(field="phone", new_value="x", confidence=1.5)
    with pytest.raises(Exception):
        Change(field="phone", new_value="x", confidence=-0.1)


def test_change_request_schema():
    cr = ChangeRequest(
        source_id=1,
        changes=[Change(field="phone", new_value="555-1111", confidence=0.95)],
        summary="Updated phone number",
    )
    assert cr.source_id == 1
    assert len(cr.changes) == 1


# ── db_apply tests ────────────────────────────────────────────────────


def test_apply_high_confidence():
    """Changes with confidence >= 0.90 should be auto-applied."""
    db = TestSessionLocal()
    _seed_source(db)

    cr = ChangeRequest(
        source_id=1,
        changes=[Change(field="phone", new_value="408-999-0000", confidence=0.95)],
        summary="Phone updated",
    )
    applied, diff = apply_changes(db, cr)
    assert applied is True
    assert diff["phone"]["new"] == "408-999-0000"

    # Verify DB was actually updated
    src = db.query(Sources).get(1)
    assert src.phone == "408-999-0000"

    # Verify audit log entry
    log = db.query(AuditLog).filter_by(source_id=1).first()
    assert log is not None
    assert log.field == "phone"
    assert log.applied is True

    db.close()


def test_apply_low_confidence_creates_proposal():
    """Changes below threshold should be stored as pending proposals."""
    db = TestSessionLocal()
    _seed_source(db)

    cr = ChangeRequest(
        source_id=1,
        changes=[Change(field="phone", new_value="408-000-0000", confidence=0.50)],
        summary="Uncertain phone",
    )
    applied, diff = apply_changes(db, cr)
    assert applied is False
    assert diff is None

    # Source should be unchanged
    src = db.query(Sources).get(1)
    assert src.phone == "408-555-0101"

    # Pending proposal should exist
    prop = db.query(PendingProposal).filter_by(source_id=1).first()
    assert prop is not None
    assert prop.status == "pending"

    db.close()


def test_apply_missing_source():
    db = TestSessionLocal()
    cr = ChangeRequest(
        source_id=999,
        changes=[Change(field="phone", new_value="x", confidence=0.99)],
    )
    applied, diff = apply_changes(db, cr)
    assert applied is False
    assert diff is None
    db.close()


def test_apply_empty_changes():
    db = TestSessionLocal()
    _seed_source(db)
    cr = ChangeRequest(source_id=1, changes=[])
    applied, diff = apply_changes(db, cr)
    assert applied is False
    db.close()


def test_apply_disallowed_field_skipped():
    """Fields not in ALLOWED_FIELDS should be silently skipped."""
    db = TestSessionLocal()
    _seed_source(db)

    cr = ChangeRequest(
        source_id=1,
        changes=[
            Change(field="lat", new_value=0.0, confidence=0.99),  # not allowed
        ],
        summary="Trying to change lat",
    )
    applied, diff = apply_changes(db, cr)
    # applied is True (all confident) but diff is empty because field was skipped
    assert applied is True
    assert diff == {}

    db.close()


# ── /ingest_call endpoint tests (Ollama mocked) ─────────────────────


MOCK_OLLAMA_RESPONSE = json.dumps({
    "source_id": 1,
    "changes": [
        {"field": "phone", "new_value": "408-777-7777", "confidence": 0.95}
    ],
    "summary": "Updated phone from transcript",
})


@patch("voice.ollama_client.requests.post")
def test_ingest_call_applies(mock_post):
    """POST /ingest_call should apply high-confidence changes."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": MOCK_OLLAMA_RESPONSE}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    resp = client.post("/ingest_call", json={
        "source_id": 1,
        "transcript": "Hi, our new phone number is 408-777-7777.",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["applied"] is True
    assert data["diff"]["phone"]["new"] == "408-777-7777"
    assert data["proposed_change"] is not None


@patch("voice.ollama_client.requests.post")
def test_ingest_call_low_confidence(mock_post):
    """Low-confidence changes should not be auto-applied."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    low_conf = json.dumps({
        "source_id": 1,
        "changes": [
            {"field": "phone", "new_value": "000-000-0000", "confidence": 0.40}
        ],
        "summary": "Uncertain",
    })
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": low_conf}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    resp = client.post("/ingest_call", json={
        "source_id": 1,
        "transcript": "Maybe they changed the phone?",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["applied"] is False


@patch("voice.ollama_client.requests.post")
def test_ingest_call_ollama_failure(mock_post):
    """When Ollama is unreachable, endpoint should return gracefully."""
    mock_post.side_effect = requests_lib.exceptions.ConnectionError("connection refused")

    resp = client.post("/ingest_call", json={
        "source_id": 1,
        "transcript": "Anything",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["applied"] is False
    assert data["proposed_change"] is None
