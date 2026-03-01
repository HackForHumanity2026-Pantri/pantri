import uuid
from typing import Optional, List
from math import radians, cos, sin, asin, sqrt
from datetime import datetime

import requests as http_requests
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from models.models import Sources, Restaurants, Buses
from models.schemas import SourceCreate, RestaurantCreate
from get_db import get_db

router = APIRouter()


def is_open_now(hours_json: list) -> bool:
    if not hours_json:
        return True
    now = datetime.now()
    today = now.strftime("%a")  # "Mon", "Tue", etc.
    current_time = now.strftime("%H:%M")
    for entry in hours_json:
        if entry.get("day") == today:
            return entry["open"] <= current_time <= entry["close"]
    return False  # no entry for today means closed


def haversine(lat1, lon1, lat2, lon2):
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * asin(sqrt(a)) * 6371


def geocode_address(address: str):
    response = http_requests.get(
        "https://nominatim.openstreetmap.org/search",
        params={"q": address, "format": "json", "limit": 1},
        headers={"User-Agent": "pantri-app"},
        timeout=5,
    )
    data = response.json()
    if not data:
        return None, None
    return float(data[0]["lat"]), float(data[0]["lon"])


def source_to_dict(source):
    return {k: v for k, v in source.__dict__.items() if not k.startswith("_")}


def format_hours_string(hours_json: list) -> str:
    """Convert hours_json array to a human-readable string."""
    if not hours_json:
        return ""
    parts = []
    for entry in hours_json:
        day = entry.get("day", "")
        open_t = entry.get("open", "")
        close_t = entry.get("close", "")
        parts.append(f"{day} {open_t}-{close_t}")
    return ", ".join(parts)


def source_to_api_response(source, user_lat=None, user_lng=None):
    """Convert a DB source model to the JSON format expected by the iOS app."""
    source_uuid = str(uuid.uuid5(uuid.NAMESPACE_OID, f"pantri-source-{source.id}"))
    open_now = is_open_now(source.hours_json) if source.hours_json else True
    hours_str = format_hours_string(source.hours_json) if source.hours_json else ""

    food_types = []
    if source.types_json:
        for t in source.types_json:
            lower = t.lower()
            if "groceries" in lower or "produce" in lower or "fresh" in lower:
                food_types.append("Groceries")
            elif "cooked" in lower or "meal" in lower or "restaurant" in lower:
                food_types.append("Cooked Meals")
        food_types = list(dict.fromkeys(food_types))

    source_type = "Food Bank"
    if source.type:
        st = source.type.lower()
        if "restaurant" in st:
            source_type = "Restaurant"
        elif "pop" in st:
            source_type = "Pop-up"

    distance_km = None
    if user_lat and user_lng and source.lat and source.lng:
        distance_km = round(haversine(user_lat, user_lng, float(source.lat), float(source.lng)), 2)

    return {
        "id": source_uuid,
        "name": source.name or "",
        "phone": source.phone or "",
        "address": source.address or "",
        "city": source.city or "",
        "state": source.state or "",
        "latitude": float(source.lat) if source.lat else 0.0,
        "longitude": float(source.lng) if source.lng else 0.0,
        "sourceType": source_type,
        "foodTypes": food_types if food_types else ["Groceries"],
        "hoursOfOperation": hours_str,
        "duration": source.duration.capitalize() if source.duration else "Permanent",
        "publicTransitAccessible": bool(source.is_accessible) if source.is_accessible is not None else False,
        "availability": (source.availability or "Medium").capitalize(),
        "hasExcessFood": bool(source.excess_food) if source.excess_food is not None else False,
        "isVerified": True,
        "isOpen": open_now,
        "lastVerified": None,
        "waitTimeEstimate": None,
        "distance_km": distance_km,
    }


@router.get("/sources")
async def get_sources(
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    type: Optional[str] = None,
    openNow: Optional[bool] = None,
    db: Session = Depends(get_db),
):
    sources = db.query(Sources).all()

    if type:
        normalized = type.lower()
        sources = [
            s for s in sources
            if s.types_json and any(normalized in t.lower() for t in s.types_json)
        ]

    results = [source_to_api_response(s, lat, lng) for s in sources]

    if openNow:
        results = [r for r in results if r["isOpen"]]

    if lat is not None and lng is not None:
        results.sort(key=lambda x: (x["distance_km"] is None, x["distance_km"] or 0))

    return results


@router.get("/sources/search")
async def search_sources(
    food_type: Optional[str] = None,
    urgent_level: Optional[str] = None,
    transportation: Optional[str] = None,
    address: Optional[str] = None,
    city: Optional[str] = None,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    zip: Optional[str] = None,
    db: Session = Depends(get_db),
):
    if address:
        lat, lng = geocode_address(address)
        if lat is None:
            raise HTTPException(status_code=400, detail="Could not geocode address. Try a more specific address.")

    sources = db.query(Sources).all()

    if food_type:
        normalized = food_type.lower()
        sources = [
            s for s in sources
            if s.types_json and any(normalized in t.lower() for t in s.types_json)
        ]

    if city:
        sources = [s for s in sources if s.city and s.city.lower() == city.lower()]

    if zip:
        sources = [s for s in sources if s.zip and s.zip == zip]

    sources = [s for s in sources if is_open_now(s.hours_json)]

    if transportation == "bus":
        sources = [s for s in sources if s.is_accessible]

    DISTANCE_LIMITS = {
        "high":   {"walking": 1,  "bike": 3,  "bus": 5,  "car": 15},
        "medium": {"walking": 2,  "bike": 8,  "bus": 15, "car": 40},
        "low":    {"walking": 5,  "bike": 15, "bus": 30, "car": 80},
    }
    limit = DISTANCE_LIMITS.get(urgent_level, {}).get(transportation)

    results = []
    for source in sources:
        entry = source_to_api_response(source, lat, lng)

        if lat is not None and lng is not None and entry["distance_km"] is not None:
            if limit is not None and entry["distance_km"] >= limit:
                continue

        results.append(entry)

    results.sort(key=lambda x: (x["distance_km"] is None, x["distance_km"] or 0))
    return results

@router.post("/sources", status_code=201)
def create_source(body: SourceCreate, db: Session = Depends(get_db)):
    lat, lng = None, None
    if body.address:
        lat, lng = geocode_address(body.address)

    source = Sources(
        name=body.name,
        phone=body.phone,
        address=body.address,
        city=body.city,
        state=body.state,
        zip=body.zip,
        lat=lat,
        lng=lng,
        types_json=[e for e in body.types_json] if body.types_json else None,
        hours_json=[e.model_dump() for e in body.hours_json] if body.hours_json else None,
        duration=body.duration,
        is_accessible= body.is_accessible if body.is_accessible is not None else False,
        availability=body.availability,
        excess_food=body.excess_food,
    )
    db.add(source)
    db.commit()
    db.refresh(source)
    return source_to_api_response(source)


@router.post("/restaurants", status_code=201)
def create_restaurant(body: RestaurantCreate, db: Session = Depends(get_db)):
    lat, lng = None, None
    if body.address:
        lat, lng = geocode_address(body.address)

    restaurant = Restaurants(
        name=body.name,
        phone=body.phone,
        address=body.address,
        city=body.city,
        state=body.state,
        zip=body.zip,
        lat=lat,
        lng=lng,
        types_json=[e for e in body.types_json] if body.types_json else None,
        hours_json=[e.model_dump() for e in body.hours_json] if body.hours_json else None,
        duration=body.duration,
        availability=body.availability,
        excess_food=body.excess_food,
    )
    db.add(restaurant)
    db.commit()
    db.refresh(restaurant)
    return source_to_dict(restaurant)
