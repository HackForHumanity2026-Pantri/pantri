"""Tests for the /call/ingest Ollama pipeline.

Ollama is mocked so tests run without a live LLM server.
"""

import os
import sys
import json
from pathlib import Path
from unittest.mock import patch, MagicMock

# Must set env before imports
os.environ["DATABASE_URL"] = "sqlite:///test_pantri.db"
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from pydantic import ValidationError
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from get_db import Base, get_db
from main import app
from models.models import Sources
from voice.models import AuditLog, PendingProposal
from schemas.proposed_change import (
    Change,
    ProposedChange,
    ALLOWED_FIELDS,
    ALLOWED_OPS,
)
from services.apply_changes import apply_proposed_change, CONFIDENCE_THRESHOLD

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


# ── Schema tests ─────────────────────────────────────────────────────


def test_change_schema_valid():
    c = Change(field="phone", op="set", value="555-1111")
    assert c.field == "phone"
    assert c.op == "set"
    assert c.value == "555-1111"


def test_change_schema_disallowed_field():
    with pytest.raises(ValidationError):
        Change(field="lat", op="set", value=0.0)


def test_change_schema_disallowed_op():
    with pytest.raises(ValidationError):
        Change(field="phone", op="delete", value="x")


def test_proposed_change_schema():
    pc = ProposedChange(
        source_id="1",
        confidence=0.95,
        changes=[Change(field="phone", op="set", value="555-1111")],
        evidence=["our phone number is 555-1111"],
    )
    assert pc.source_id == "1"
    assert len(pc.changes) == 1
    assert len(pc.evidence) == 1


def test_proposed_change_confidence_bounds():
    with pytest.raises(ValidationError):
        ProposedChange(source_id="1", confidence=1.5, changes=[])
    with pytest.raises(ValidationError):
        ProposedChange(source_id="1", confidence=-0.1, changes=[])


def test_allowed_fields_constant():
    expected = {"hours", "phone", "address", "food_type",
                "isAccessibleViaPublicTransport", "notes", "wait_time"}
    assert ALLOWED_FIELDS == expected


def test_allowed_ops_constant():
    assert ALLOWED_OPS == {"set"}


# ── apply_proposed_change tests ──────────────────────────────────────


def test_apply_high_confidence():
    """Changes with confidence >= 0.90 should be auto-applied."""
    db = TestSessionLocal()
    _seed_source(db)

    proposed = ProposedChange(
        source_id="1",
        confidence=0.95,
        changes=[Change(field="phone", op="set", value="408-999-0000")],
        evidence=["our phone number changed to 408-999-0000"],
    )
    applied, diff = apply_proposed_change(db, proposed)
    assert applied is True
    assert diff["phone"]["new"] == "408-999-0000"

    # Verify DB was actually updated
    src = db.get(Sources, 1)
    assert src.phone == "408-999-0000"

    # Verify audit log entry
    log = db.query(AuditLog).filter_by(source_id=1).first()
    assert log is not None
    assert log.field == "phone"
    assert log.applied is True

    db.close()


def test_apply_low_confidence_creates_pending():
    """Changes below threshold should be stored as pending."""
    db = TestSessionLocal()
    _seed_source(db)

    proposed = ProposedChange(
        source_id="1",
        confidence=0.50,
        changes=[Change(field="phone", op="set", value="000-000-0000")],
        evidence=["maybe the phone changed"],
    )
    applied, diff = apply_proposed_change(db, proposed)
    assert applied is False
    assert diff is None

    # Source should be unchanged
    src = db.get(Sources, 1)
    assert src.phone == "408-555-0101"

    # Pending proposal should exist
    prop = db.query(PendingProposal).filter_by(source_id=1).first()
    assert prop is not None
    assert prop.status == "pending"

    db.close()


def test_apply_missing_source():
    db = TestSessionLocal()
    proposed = ProposedChange(
        source_id="999",
        confidence=0.99,
        changes=[Change(field="phone", op="set", value="x")],
    )
    applied, diff = apply_proposed_change(db, proposed)
    assert applied is False
    assert diff is None
    db.close()


def test_apply_empty_changes():
    db = TestSessionLocal()
    _seed_source(db)
    proposed = ProposedChange(source_id="1", confidence=0.99, changes=[])
    applied, diff = apply_proposed_change(db, proposed)
    assert applied is False
    db.close()


# ── /call/ingest endpoint tests (Ollama mocked) ─────────────────────


MOCK_OLLAMA_RESPONSE = json.dumps({
    "source_id": "1",
    "confidence": 0.95,
    "changes": [
        {"field": "phone", "op": "set", "value": "408-777-7777"}
    ],
    "evidence": ["our phone number is 408-777-7777"],
})


@patch("services.ollama_client.requests.post")
def test_call_ingest_high_confidence_applies(mock_post):
    """POST /call/ingest with high confidence should auto-apply changes."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": MOCK_OLLAMA_RESPONSE}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    resp = client.post("/call/ingest", json={
        "source_id": "1",
        "transcript": "Our new phone number is 408-777-7777.",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["proposed_change"] is not None
    assert data["applied"] is True
    assert data["diff"]["phone"]["new"] == "408-777-7777"


@patch("services.ollama_client.requests.post")
def test_call_ingest_low_confidence_not_applied(mock_post):
    """POST /call/ingest with low confidence should NOT auto-apply."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    low_conf = json.dumps({
        "source_id": "1",
        "confidence": 0.40,
        "changes": [
            {"field": "phone", "op": "set", "value": "000-000-0000"}
        ],
        "evidence": ["maybe the phone changed"],
    })
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": low_conf}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    resp = client.post("/call/ingest", json={
        "source_id": "1",
        "transcript": "Maybe they changed the phone?",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["applied"] is False


@patch("services.ollama_client.requests.post")
def test_call_ingest_ollama_failure(mock_post):
    """When Ollama is unreachable, endpoint should return gracefully."""
    import requests as requests_lib
    mock_post.side_effect = requests_lib.exceptions.ConnectionError("connection refused")

    resp = client.post("/call/ingest", json={
        "source_id": "1",
        "transcript": "Anything",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["applied"] is False
    assert data["proposed_change"] is None


@patch("services.ollama_client.requests.post")
def test_call_ingest_invalid_json_from_ollama(mock_post):
    """When Ollama returns non-JSON, endpoint should return gracefully."""
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": "not valid json at all"}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    resp = client.post("/call/ingest", json={
        "source_id": "1",
        "transcript": "Anything",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["applied"] is False
    assert data["proposed_change"] is None


@patch("services.ollama_client.requests.post")
def test_call_ingest_no_changes(mock_post):
    """When transcript has no actionable data, return empty changes."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    no_changes = json.dumps({
        "source_id": "1",
        "confidence": 0.95,
        "changes": [],
        "evidence": [],
    })
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": no_changes}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    resp = client.post("/call/ingest", json={
        "source_id": "1",
        "transcript": "Everything is the same.",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["proposed_change"] is not None
    assert data["applied"] is False
    assert len(data["proposed_change"]["changes"]) == 0


# ── Prompt template tests ────────────────────────────────────────────


def test_ollama_client_prompt_includes_source_id():
    from services.ollama_client import PROMPT_TEMPLATE
    rendered = PROMPT_TEMPLATE.format(source_id="42", transcript="test")
    assert "42" in rendered
    assert "test" in rendered


def test_ollama_client_prompt_requires_json():
    from services.ollama_client import PROMPT_TEMPLATE
    assert "valid JSON" in PROMPT_TEMPLATE
    assert "no markdown" in PROMPT_TEMPLATE.lower() or "No markdown" in PROMPT_TEMPLATE
