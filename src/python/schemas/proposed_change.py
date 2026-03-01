"""Pydantic schemas for the /call/ingest Ollama pipeline."""

from typing import Any, List, Optional

from pydantic import BaseModel, Field, field_validator

# Fields the LLM is allowed to propose changes for.
ALLOWED_FIELDS = {
    "hours",
    "phone",
    "address",
    "food_type",
    "isAccessibleViaPublicTransport",
    "notes",
    "wait_time",
}

ALLOWED_OPS = {"set"}


class Change(BaseModel):
    """A single field mutation extracted from a transcript."""

    field: str
    op: str = Field("set", description="Operation to perform (only 'set' is allowed)")
    value: Any

    @field_validator("field")
    @classmethod
    def field_must_be_allowed(cls, v: str) -> str:
        if v not in ALLOWED_FIELDS:
            raise ValueError(
                f"Field '{v}' not allowed. Must be one of: {sorted(ALLOWED_FIELDS)}"
            )
        return v

    @field_validator("op")
    @classmethod
    def op_must_be_allowed(cls, v: str) -> str:
        if v not in ALLOWED_OPS:
            raise ValueError(
                f"Op '{v}' not allowed. Must be one of: {sorted(ALLOWED_OPS)}"
            )
        return v


class ProposedChange(BaseModel):
    """Full proposed change set returned by Ollama."""

    source_id: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    changes: List[Change] = []
    evidence: List[str] = []


# ── FastAPI request / response ──────────────────────────────────────

class CallIngestRequest(BaseModel):
    source_id: str
    transcript: str
    call_time: Optional[str] = None


class CallIngestResponse(BaseModel):
    proposed_change: Optional[ProposedChange] = None
    applied: bool = False
    diff: Optional[dict] = None
