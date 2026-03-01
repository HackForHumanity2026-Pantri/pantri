"""Apply validated ProposedChange to the database with audit logging."""

import json
import logging
from typing import Dict, Optional, Tuple

from sqlalchemy.orm import Session

from models.models import Sources
from voice.models import AuditLog, PendingProposal
from schemas.proposed_change import ProposedChange

logger = logging.getLogger(__name__)

CONFIDENCE_THRESHOLD = 0.90

# Mapping from LLM field names → actual Sources column names.
FIELD_MAP: Dict[str, str] = {
    "hours": "hours_json",
    "phone": "phone",
    "address": "address",
    "food_type": "types_json",
    "isAccessibleViaPublicTransport": "is_accessible",
    "notes": "notes",
    "wait_time": "duration",
}


def apply_proposed_change(
    db: Session,
    proposed: ProposedChange,
    transcript: str = "",
) -> Tuple[bool, Optional[Dict]]:
    """Validate and apply *proposed* inside a single transaction.

    Returns ``(applied, diff)`` where *applied* is ``True`` only when
    confidence meets the threshold and changes were written to the database.
    """

    source: Optional[Sources] = db.get(Sources, int(proposed.source_id))
    if source is None:
        logger.error("Source %s not found", proposed.source_id)
        return False, None

    if not proposed.changes:
        return False, None

    auto_apply = proposed.confidence >= CONFIDENCE_THRESHOLD

    if auto_apply:
        diff: Dict = {}
        try:
            for change in proposed.changes:
                col_name = FIELD_MAP.get(change.field)
                if col_name is None:
                    logger.warning("Skipping unmapped field: %s", change.field)
                    continue

                old_val = getattr(source, col_name, None)
                setattr(source, col_name, change.value)
                diff[change.field] = {"old": old_val, "new": change.value}

                db.add(AuditLog(
                    source_id=int(proposed.source_id),
                    field=col_name,
                    old_value=json.dumps(old_val) if old_val is not None else None,
                    new_value=json.dumps(change.value) if change.value is not None else None,
                    confidence=proposed.confidence,
                    applied=True,
                    raw_transcript=transcript or None,
                    extracted_json=proposed.model_dump(),
                ))

            db.commit()
        except Exception:
            db.rollback()
            logger.exception("Failed to apply changes for source %s", proposed.source_id)
            return False, None

        logger.info("Applied %d change(s) to source %s", len(diff), proposed.source_id)
        return True, diff

    # Below threshold → store as pending proposal.
    try:
        db.add(PendingProposal(
            source_id=int(proposed.source_id),
            changes_json=proposed.model_dump(),
            summary=f"Low-confidence proposal ({proposed.confidence:.2f})",
            transcript=transcript,
            status="pending",
        ))
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Failed to store pending proposal for source %s", proposed.source_id)

    logger.info("Stored pending proposal for source %s (confidence %.2f)", proposed.source_id, proposed.confidence)
    return False, None
