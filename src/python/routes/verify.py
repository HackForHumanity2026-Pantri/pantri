from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from models.models import Sources
from get_db import get_db

router = APIRouter()


@router.post("/verify/{source_id}")
async def verify_source(source_id: int, db: Session = Depends(get_db)):
    """Mark a source as verified (simulates phone-bot verification)."""
    source = db.query(Sources).filter(Sources.id == source_id).first()
    if not source:
        raise HTTPException(status_code=404, detail="Source not found")

    source.availability = source.availability or "Medium"
    db.commit()
    db.refresh(source)
    return {"status": "verified", "source_id": source_id}
