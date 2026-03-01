from fastapi import APIRouter, Depends
from models.models import Sources
from sqlalchemy.orm import Session
from get_db import get_db

router = APIRouter()

class SourceWithDistance(Sources): # inherit from source and add distance
    distance_km = float

@router.get("/sources")
async def get_sources(db: Session = Depends(get_db)):
    sources = db.query(Sources).all()
    return sources

@router.get("/sources_closest")
async def get_sources_closest(my_lat: float, my_long: float, db: Session = Depends(get_db)):
    sources = db.query(Sources).all()
    results = [
        SourceWithDistance(**source.__dict__, distance_km = haversine(my_lat, my_long, float(source.lat), float(source.lng)))
        for source in sources
    ]
    results.sort(key = lambda x: x.distance_km)
    return results[:10]

def haversine(lat1, lon1, lat2, lon2):
    from math import radians, cos, sin, asin, sqrt

    # convert decimal degrees to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])

    # haversine formula
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    r = 6371
    return c * r


