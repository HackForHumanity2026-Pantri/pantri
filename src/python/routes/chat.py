from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from models.models import Sources
from get_db import get_db

router = APIRouter()


class ChatRequest(BaseModel):
    message: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


@router.post("/chat")
async def chat(body: ChatRequest, db: Session = Depends(get_db)):
    """Simple keyword-based chat assistant for food finding."""
    lower = body.message.lower()

    sources = db.query(Sources).all()
    open_sources = [s for s in sources if s.types_json]

    if "hungry" in lower or "food" in lower or "eat" in lower or "meal" in lower:
        meal_sources = [
            s for s in open_sources
            if any("cooked" in t.lower() or "meal" in t.lower() or "restaurant" in t.lower() for t in (s.types_json or []))
        ]
        if meal_sources:
            best = meal_sources[0]
            return {
                "reply": f"I found a great option for you! {best.name} at {best.address or 'address not available'} "
                         f"has cooked meals available. Would you like directions?"
            }
        return {"reply": "I'm looking for cooked meal options near you. Could you share your location or ZIP code so I can find the closest options?"}

    if "grocer" in lower or "produce" in lower or "fresh" in lower:
        grocery_sources = [
            s for s in open_sources
            if any("grocer" in t.lower() or "produce" in t.lower() or "fresh" in t.lower() for t in (s.types_json or []))
        ]
        if grocery_sources:
            best = grocery_sources[0]
            return {
                "reply": f"For groceries, I'd recommend {best.name} at {best.address or 'address not available'}. "
                         f"Want me to show you how to get there?"
            }
        return {"reply": "Let me find grocery sources near you. What's your ZIP code or neighborhood?"}

    if "direction" in lower or "how to get" in lower or "map" in lower:
        return {
            "reply": "Tap the 'Directions' button on any match card to open Apple Maps with turn-by-turn directions. "
                     "If you prefer public transit, make sure to set that in your transportation preferences!"
        }

    if "hi" in lower or "hello" in lower or "hey" in lower:
        return {
            "reply": "Hi there! I'm Pantri, your food-finding assistant. I can help you find cooked meals or groceries nearby. What are you looking for today?"
        }

    if "thank" in lower:
        return {
            "reply": "You're welcome! Remember, you can always come back to find more food sources. Take care! 💚"
        }

    return {
        "reply": "I can help you find food nearby! Try asking about cooked meals, groceries, or tell me what you need and I'll find the best match for you."
    }
