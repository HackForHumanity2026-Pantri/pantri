from math import radians, cos, sin, asin, sqrt

from sqlalchemy.orm import Session

from models.models import Buses

BUS_PROXIMITY_KM = 0.5  # must be within 500m of a bus stop to be considered accessible


def _haversine(lat1, lon1, lat2, lon2):
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * asin(sqrt(a)) * 6371


def mark_bus_accessible(sources, db: Session):
    """
    For each source/restaurant, check if it is within BUS_PROXIMITY_KM of any
    bus stop. If so, persist accessible=True to the DB.
    Returns the same list with accessibility updated in-place.
    """
    bus_stops = db.query(Buses).all()
    bus_coords = [
        (b.lat, b.lng) for b in bus_stops if b.lat is not None and b.lng is not None
    ]

    changed = False
    for source in sources:
        if source.lat is None or source.lng is None:
            continue
        near_bus = any(
            _haversine(source.lat, source.lng, blat, blng) <= BUS_PROXIMITY_KM
            for blat, blng in bus_coords
        )
        source.is_accessible = near_bus
        changed = True

    if changed:
        db.commit()

    return sources
