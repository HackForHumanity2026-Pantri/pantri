import json
from pathlib import Path
from sqlalchemy.orm import Session
from sqlalchemy import inspect

from models.models import Sources, Restaurants, Buses
from get_db import engine


def seed_from_json(db: Session, model, json_filename: str, mapping: dict):
    """
    Generic seeder for any model + JSON file.
    """
    filepath = Path(__file__).resolve().parent.parent / json_filename

    with open(filepath, "r") as f:
        data = json.load(f)

    count = 0
    for item in data:
        kwargs = {model_field: item[src_field] for model_field, src_field in mapping.items()}
        obj = model(**kwargs)
        db.add(obj)
        count += 1

    db.commit()
    print(f"Seeded {count} rows into '{model.__tablename__}' table.")


def init_db(db: Session):
    inspector = inspect(engine)

    # --- Check tables exist ---
    if not inspector.has_table("sources"):
        print("Sources table does not exist, skipping initialization.")
        return
    if not inspector.has_table("restaurants"):
        print("Restaurants table does not exist, skipping initialization.")
        return
    if not inspector.has_table("buses"):
        print("Buses table does not exist, skipping initialization.")
        return

    # --- Skip if already seeded ---
    if db.query(Sources).first():
        print("Sources table already has data, skipping initialization.")
        return
    if db.query(Restaurants).first():
        print("Restaurants table already has data, skipping initialization.")
        return
    if db.query(Buses).first():
        print("Buses table already has data, skipping initialization.")
        return

    print("Seeding database...")

    # --- Seed SOURCES (Food Banks) ---
    seed_from_json(
        db,
        Sources,
        "json_files/food_banks.json",
        mapping={
            "id": "id",
            "name": "name",
            "type": "type",
            "duration": "duration",
            "address": "address",
            "state": "state",
            "city": "city",
            "zip": "zip",
            "lat": "lat",
            "lng": "lng",
            "phone": "phone",
            "hours_json": "hours_json",
            "types_json": "types_json",
        },
    )

    # --- Seed RESTAURANTS ---
    seed_from_json(
        db,
        Restaurants,
        "json_files/rest.json",
        mapping={
            "id": "id",
            "name": "name",
            "type": "type",
            "duration": "duration",
            "address": "address",
            "state": "state",
            "city": "city",
            "zip": "zip",
            "lat": "lat",
            "lng": "lng",
            "phone": "phone",
            "hours_json": "hours_json",
            "types_json": "types_json",
        },
    )

    # --- Seed BUSES ---
    seed_from_json(
        db,
        Buses,
        "json_files/buses.json",
        mapping={
            "id": "id",
            "name": "name",
            "lat": "lat",
            "lng": "lon",
        },
    )

    print("Database seeding complete.")
