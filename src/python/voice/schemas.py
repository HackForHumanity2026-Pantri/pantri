"""Pydantic models for the voice-verification agent pipeline."""

from datetime import datetime
from typing import List, Optional, Any

from pydantic import BaseModel, Field, field_validator

# Fields the LLM is allowed to propose changes for.
ALLOWED_FIELDS = {
    "hours",
    "phone",
    "address",
    "food_type",
    "isAccessibleViaPublicTransport",
    "wait_time",
}


class Change(BaseModel):
    """A single proposed field change extracted from a call transcript."""

    field: str = Field(..., description="Column name on the Sources table")
    old_value: Optional[Any] = Field(None, description="Previous value (if known)")
    new_value: Any = Field(..., description="Proposed new value")
    confidence: float = Field(
        ..., ge=0.0, le=1.0, description="Model confidence 0-1"
    )
    evidence: Optional[str] = Field(
        None, description="Verbatim sentence(s) from transcript supporting this change"
    )

    @field_validator("field")
    @classmethod
    def field_must_be_allowed(cls, v: str) -> str:
        if v not in ALLOWED_FIELDS:
            raise ValueError(
                f"Field '{v}' is not allowed. Must be one of: {sorted(ALLOWED_FIELDS)}"
            )
        return v


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
