"""FastAPI router for the voice-verification agent pipeline."""

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from get_db import get_db
from .agent_extract import extract_changes
from .db_apply import apply_changes
from .schemas import IngestCallRequest, IngestCallResponse

logger = logging.getLogger(__name__)

router = APIRouter(tags=["voice"])


@router.post("/ingest_call", response_model=IngestCallResponse)
def ingest_call(body: IngestCallRequest, db: Session = Depends(get_db)):
    """Accept a call transcript and return proposed / applied changes."""

    call_time = body.call_time or datetime.now(timezone.utc)

    change_req = extract_changes(body.source_id, body.transcript)
    if change_req is None:
        return IngestCallResponse(proposed_change=None, applied=False, diff=None)

    try:
        applied, diff = apply_changes(db, change_req, transcript=body.transcript)
    except Exception:
        logger.exception("Error applying changes for source %s", body.source_id)
        return IngestCallResponse(proposed_change=change_req, applied=False, diff=None)

    return IngestCallResponse(
        proposed_change=change_req,
        applied=applied,
        diff=diff,
    )
