"""Pydantic models for the voice-verification agent pipeline."""

from datetime import datetime
from typing import List, Optional, Any

from pydantic import BaseModel, Field


class Change(BaseModel):
    """A single proposed field change extracted from a call transcript."""

    field: str = Field(..., description="Column name on the Sources table")
    old_value: Optional[Any] = Field(None, description="Previous value (if known)")
    new_value: Any = Field(..., description="Proposed new value")
    confidence: float = Field(
        ..., ge=0.0, le=1.0, description="Model confidence 0-1"
    )


class ChangeRequest(BaseModel):
    """Full set of changes proposed by the LLM for a single source."""

    source_id: int
    changes: List[Change]
    summary: str = Field("", description="Human-readable summary of all changes")


# ── FastAPI request / response ──────────────────────────────────────────


class IngestCallRequest(BaseModel):
    source_id: int
    transcript: str
    call_time: Optional[datetime] = None


class IngestCallResponse(BaseModel):
    proposed_change: Optional[ChangeRequest] = None
    applied: bool = False
    diff: Optional[dict] = None
