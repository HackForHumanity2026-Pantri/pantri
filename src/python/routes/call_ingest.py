"""FastAPI router for the /call/ingest Ollama pipeline."""

import logging

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from get_db import get_db
from services.ollama_client import extract_proposed_change
from services.apply_changes import apply_proposed_change
from schemas.proposed_change import (
    CallIngestRequest,
    CallIngestResponse,
    ProposedChange,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/call", tags=["call"])


@router.post("/ingest", response_model=CallIngestResponse)
def call_ingest(body: CallIngestRequest, db: Session = Depends(get_db)):
    """Accept a call transcript, run it through Ollama, and apply changes."""

    # 1. Call Ollama to extract proposed changes
    try:
        raw = extract_proposed_change(body.source_id, body.transcript)
    except (RuntimeError, ValueError) as exc:
        logger.error("Ollama extraction failed for source %s: %s", body.source_id, exc)
        return CallIngestResponse(proposed_change=None, applied=False, diff=None)

    # 2. Validate via Pydantic (never apply if parsing fails)
    try:
        proposed = ProposedChange(**raw)
    except Exception as exc:
        logger.error("Validation failed for source %s: %s", body.source_id, exc)
        return CallIngestResponse(proposed_change=None, applied=False, diff=None)

    # 3. Apply to DB (auto-apply if confidence >= 0.90)
    try:
        applied, diff = apply_proposed_change(db, proposed, transcript=body.transcript)
    except Exception:
        logger.exception("Error applying changes for source %s", body.source_id)
        return CallIngestResponse(proposed_change=proposed, applied=False, diff=None)

    return CallIngestResponse(proposed_change=proposed, applied=applied, diff=diff)
