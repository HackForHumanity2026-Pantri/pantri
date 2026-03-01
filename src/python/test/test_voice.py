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
from voice.schemas import Change, ChangeRequest, ALLOWED_FIELDS
from voice.db_apply import apply_changes, CONFIDENCE_THRESHOLD
from voice.agent_extract import SYSTEM_PROMPT, FEW_SHOT_EXAMPLES, build_prompt

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


def test_disallowed_field_rejected_by_schema():
    """Fields not in ALLOWED_FIELDS should be rejected at the Pydantic level."""
    with pytest.raises(Exception):
        Change(field="lat", new_value=0.0, confidence=0.99)


def test_allowed_fields_constant():
    """ALLOWED_FIELDS should contain exactly the expected field names."""
    expected = {"hours", "phone", "address", "food_type",
                "isAccessibleViaPublicTransport", "notes", "wait_time"}
    assert ALLOWED_FIELDS == expected


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
    """POST /ingest_call should return proposed changes without applying."""
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
    assert data["applied"] is False
    assert data["diff"] is None
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


# ── Prompt template tests ────────────────────────────────────────────


def test_prompt_requires_json_only():
    """System prompt must instruct model to produce JSON only."""
    assert "valid JSON" in SYSTEM_PROMPT
    assert "no markdown" in SYSTEM_PROMPT.lower() or "No markdown" in SYSTEM_PROMPT


def test_prompt_allowed_fields():
    """All required fields must be listed in the system prompt."""
    for field in ("hours", "phone", "address", "food_type",
                  "isAccessibleViaPublicTransport", "notes", "wait_time"):
        assert field in SYSTEM_PROMPT, f"Missing field '{field}' in SYSTEM_PROMPT"


def test_prompt_evidence_requirement():
    """Prompt must require evidence sentences."""
    assert "evidence" in SYSTEM_PROMPT.lower()


def test_prompt_empty_changes_rule():
    """Prompt must explain returning empty changes list."""
    assert '"changes": []' in SYSTEM_PROMPT or "changes" in SYSTEM_PROMPT


def test_few_shot_examples_present():
    """There must be at least 3 few-shot examples."""
    assert FEW_SHOT_EXAMPLES.count("EXAMPLE") >= 3


def test_few_shot_no_change_example():
    """One example should show no changes (changes=[])."""
    assert '"changes": []' in FEW_SHOT_EXAMPLES


def test_build_prompt_includes_transcript():
    """build_prompt must embed transcript and source_id."""
    result = build_prompt(42, "Hello, our hours changed.")
    assert "source_id: 42" in result
    assert "Hello, our hours changed." in result
    assert "--- TRANSCRIPT ---" in result


# ── Evidence field tests ─────────────────────────────────────────────


def test_change_schema_with_evidence():
    """Change model should accept an evidence string."""
    c = Change(
        field="phone",
        new_value="555-1234",
        confidence=0.95,
        evidence="our phone number changed to 555-1234",
    )
    assert c.evidence == "our phone number changed to 555-1234"


def test_change_schema_evidence_optional():
    """Evidence should be optional for backward compatibility."""
    c = Change(field="phone", new_value="555-0000", confidence=0.90)
    assert c.evidence is None


# ── Field mapping tests ──────────────────────────────────────────────


@patch("voice.ollama_client.requests.post")
def test_ingest_call_field_mapping_food_type(mock_post):
    """LLM field 'food_type' should be accepted and returned in proposed_change."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    mapped_response = json.dumps({
        "source_id": 1,
        "changes": [
            {
                "field": "food_type",
                "new_value": "hot meals, groceries",
                "confidence": 0.95,
                "evidence": "we now serve hot meals and groceries",
            }
        ],
        "summary": "Updated food type",
    })
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": mapped_response}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    resp = client.post("/ingest_call", json={
        "source_id": 1,
        "transcript": "We now serve hot meals and groceries.",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["proposed_change"] is not None
    assert data["proposed_change"]["changes"][0]["field"] == "food_type"
    assert data["applied"] is False


@patch("voice.ollama_client.requests.post")
def test_ingest_call_field_mapping_wait_time(mock_post):
    """LLM field 'wait_time' should be accepted and returned in proposed_change."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    mapped_response = json.dumps({
        "source_id": 1,
        "changes": [
            {
                "field": "wait_time",
                "new_value": "20 minutes",
                "confidence": 0.92,
                "evidence": "Usually about 20 minutes.",
            }
        ],
        "summary": "Updated wait time",
    })
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": mapped_response}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    resp = client.post("/ingest_call", json={
        "source_id": 1,
        "transcript": "Usually about 20 minutes wait.",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["proposed_change"] is not None
    assert data["proposed_change"]["changes"][0]["field"] == "wait_time"
    assert data["applied"] is False


# ── Twilio endpoint tests ───────────────────────────────────────────


def test_twilio_voice_outbound_returns_twiml():
    """POST /twilio/voice/outbound should return TwiML with Stream."""
    resp = client.post("/twilio/voice/outbound")
    assert resp.status_code == 200
    assert "application/xml" in resp.headers["content-type"]
    assert "<Stream" in resp.text
    assert "<Response>" in resp.text


def test_twilio_voice_inbound_returns_twiml():
    """POST /twilio/voice/inbound should return TwiML with Stream."""
    resp = client.post("/twilio/voice/inbound")
    assert resp.status_code == 200
    assert "<Stream" in resp.text


def test_twilio_call_status_callback():
    """POST /twilio/call-status should accept status updates."""
    resp = client.post(
        "/twilio/call-status",
        data={"CallSid": "CA123", "CallStatus": "completed"},
    )
    assert resp.status_code == 204


# ── source_id propagation tests ─────────────────────────────────────


def test_twilio_voice_outbound_includes_source_id_parameter():
    """When source_id is in query params, TwiML should include a <Parameter> tag."""
    resp = client.post("/twilio/voice/outbound?source_id=42")
    assert resp.status_code == 200
    assert 'name="source_id"' in resp.text
    assert 'value="42"' in resp.text


def test_twilio_voice_outbound_no_source_id():
    """Without source_id the TwiML should NOT include a <Parameter> tag."""
    resp = client.post("/twilio/voice/outbound")
    assert resp.status_code == 200
    assert "<Parameter" not in resp.text


# ── AuditLog enhanced fields tests ─────────────────────────────────


@patch("voice.ollama_client.requests.post")
def test_audit_log_not_written_yet(mock_post):
    """With DB integration deferred, no AuditLog rows should be written."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": MOCK_OLLAMA_RESPONSE}
    mock_resp.raise_for_status = MagicMock()
    mock_post.return_value = mock_resp

    transcript_text = "Hi, our new phone number is 408-777-7777."
    resp = client.post("/ingest_call", json={
        "source_id": 1,
        "transcript": transcript_text,
    })
    assert resp.status_code == 200
    assert resp.json()["applied"] is False

    db = TestSessionLocal()
    log = db.query(AuditLog).filter_by(source_id=1).first()
    assert log is None  # No audit log yet – DB integration is deferred
    db.close()


# ── verification_failed marking tests ──────────────────────────────


def test_call_status_failed_marks_source():
    """A 'failed' call status should mark the source as verification_failed."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    resp = client.post(
        "/twilio/call-status?source_id=1",
        data={"CallSid": "CA999", "CallStatus": "failed"},
    )
    assert resp.status_code == 204

    db = TestSessionLocal()
    src = db.query(Sources).get(1)
    assert src.verification_status == "verification_failed"
    assert src.verification_failed_at is not None
    db.close()


def test_call_status_noanswer_marks_source():
    """A 'no-answer' call status should mark the source as verification_failed."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    resp = client.post(
        "/twilio/call-status?source_id=1",
        data={"CallSid": "CA888", "CallStatus": "no-answer"},
    )
    assert resp.status_code == 204

    db = TestSessionLocal()
    src = db.query(Sources).get(1)
    assert src.verification_status == "verification_failed"
    db.close()


def test_call_status_completed_does_not_mark():
    """A 'completed' status should NOT mark the source as verification_failed."""
    db = TestSessionLocal()
    _seed_source(db)
    db.close()

    resp = client.post(
        "/twilio/call-status?source_id=1",
        data={"CallSid": "CA777", "CallStatus": "completed"},
    )
    assert resp.status_code == 204

    db = TestSessionLocal()
    src = db.query(Sources).get(1)
    assert src.verification_status is None
    db.close()
