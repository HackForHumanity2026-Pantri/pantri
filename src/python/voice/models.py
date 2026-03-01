"""SQLAlchemy models for the voice-verification pipeline."""

from datetime import datetime, timezone

from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, JSON

from get_db import Base


class PendingProposal(Base):
    """Stores proposed changes that did not meet the auto-apply threshold."""

    __tablename__ = "pending_proposals"

    id = Column(Integer, primary_key=True, index=True)
    source_id = Column(Integer, nullable=False, index=True)
    changes_json = Column(JSON, nullable=False)
    summary = Column(String, default="")
    transcript = Column(String, default="")
    status = Column(String, default="pending")  # pending | approved | rejected
    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )


class AuditLog(Base):
    """Immutable log of every change applied to a source via the voice pipeline."""

    __tablename__ = "audit_log"

    id = Column(Integer, primary_key=True, index=True)
    source_id = Column(Integer, nullable=False, index=True)
    field = Column(String, nullable=False)
    old_value = Column(String, nullable=True)
    new_value = Column(String, nullable=True)
    confidence = Column(Float, nullable=False)
    applied = Column(Boolean, default=True)
    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )
