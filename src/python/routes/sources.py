from typing import Optional
from math import radians, cos, sin, asin, sqrt
from datetime import datetime

import requests as http_requests
from fastapi import APIRouter, Depends, HTTPException
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


@router.get("/sources")
async def get_sources(db: Session = Depends(get_db)):
    return db.query(Sources).all()

'''TODO: Nothing is returned, fix the search'''
@router.get("/sources/search")
async def search_sources(
    food_type: str,
    urgent_level: str,
    transportation: str,
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
        entry = {**source_to_dict(source), "distance_km": None}

        if lat is not None and lng is not None and source.lat is not None and source.lng is not None:
            dist = round(haversine(lat, lng, float(source.lat), float(source.lng)), 2)
            entry["distance_km"] = dist
            if limit is not None and dist >= limit:
                continue

        results.append(entry)

    results.sort(key=lambda x: (x["distance_km"] is None, x["distance_km"] or 0))
    return results

@router.post("/sources", status_code=201)
def create_source(body: SourceCreate, db: Session = Depends(get_db)):
    # Auto-geocode lat/lng from address if not already in DB
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
    return source_to_dict(source)


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
