"""Apply validated ChangeRequests to the database with audit logging."""

import json
import logging
from typing import Optional, Dict

from sqlalchemy.orm import Session

from models.models import Sources
from .models import AuditLog, PendingProposal
from .schemas import ChangeRequest

logger = logging.getLogger(__name__)

CONFIDENCE_THRESHOLD = 0.90

# Columns that may be updated via the voice pipeline.
ALLOWED_FIELDS = {
    "name", "phone", "address", "city", "state", "zip",
    "hours_json", "types_json", "availability", "excess_food",
    "is_accessible", "duration",
}


def apply_changes(
    db: Session,
    change_req: ChangeRequest,
    transcript: str = "",
) -> tuple[bool, Optional[Dict]]:
    """Validate and apply *change_req* inside a single transaction.

    Returns ``(applied, diff)`` where *applied* is ``True`` only when every
    change met the confidence threshold and was written to the database.
    """

    source: Optional[Sources] = db.query(Sources).get(change_req.source_id)
    if source is None:
        logger.error("Source %s not found", change_req.source_id)
        return False, None

    if not change_req.changes:
        return False, None

    # Check whether all changes meet the auto-apply threshold.
    all_confident = all(c.confidence >= CONFIDENCE_THRESHOLD for c in change_req.changes)

    diff: Dict = {}

    if all_confident:
        for change in change_req.changes:
            if change.field not in ALLOWED_FIELDS:
                logger.warning("Skipping disallowed field: %s", change.field)
                continue

            old_val = getattr(source, change.field, None)
            setattr(source, change.field, change.new_value)
            diff[change.field] = {"old": old_val, "new": change.new_value}

            db.add(AuditLog(
                source_id=change_req.source_id,
                field=change.field,
                old_value=json.dumps(old_val) if old_val is not None else None,
                new_value=json.dumps(change.new_value),
                confidence=change.confidence,
                applied=True,
            ))

        db.commit()
        logger.info(
            "Applied %d change(s) to source %s",
            len(diff),
            change_req.source_id,
        )
        return True, diff

    # Below threshold → store as pending proposal.
    db.add(PendingProposal(
        source_id=change_req.source_id,
        changes_json=[c.model_dump() for c in change_req.changes],
        summary=change_req.summary,
        transcript=transcript,
        status="pending",
    ))
    db.commit()
    logger.info(
        "Stored pending proposal for source %s (low confidence)",
        change_req.source_id,
    )
    return False, None
